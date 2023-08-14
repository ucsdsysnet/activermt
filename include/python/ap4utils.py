import os

from scapy.all import *
from headers import *

class AP4Utils:
    def __init__(self):
        pass

    def readConfigs(self):
        self.mnemonic_opcode = {}
        self.opcode_mnemonic = {}
        with open(os.path.join(os.environ['ACTIVEP4_SRC'], 'config', 'opcode_action_mapping.csv')) as f:
            mapping = f.read().strip().splitlines()
            for opcode in range(0, len(mapping)):
                m = mapping[opcode].split(',')
                mnemonic = m[0]
                self.mnemonic_opcode[mnemonic] = opcode
                self.opcode_mnemonic[opcode] = mnemonic
            f.close()

    def readActiveProgram(self, program_name, base_dir="apps", print_bytecode=False):
        active_program_src = os.path.join(base_dir, "%s.apo" % program_name)
        active_program_args = os.path.join(base_dir, "%s.args.csv" % program_name)
        bytecode = []
        args = {}
        bulk_args = {}
        with open(active_program_src, 'rb') as f:
            data = list(f.read())
            i = 0
            while i < len(data):
                bytecode.append({
                    'opcode'    : data[i + 1],
                    'goto'      : data[i]
                })
                i = i + 2
            f.close()
        """with open(active_program_args) as f:
            data = f.read().splitlines()
            for d in data:
                row = d.split(',')
                var = row[0]
                idx = int(row[1])
                didx = int(row[2])
                is_bulk = (int(row[3]) == 1) 
                if is_bulk:
                    bulk_args[var] = idx
                else:
                    args[didx] = var
            f.close()"""
        if print_bytecode:
            print("Bytecode: %s" % str(bytecode))
        return (bytecode, args, bulk_args)

    def constructBulkArgs(self, arg_pfx, value_str, argvals):
        bulk_write_len = 10
        value_len_bytes = bulk_write_len * 4
        self.assertTrue(len(value_str) <= value_len_bytes)
        i = 0
        vidx = 0
        while(i < len(value_str)):
            word = 0x00000000
            j = 3
            while(i < len(value_str) and j >= 0):
                word = word | (ord(value_str[i]) << (8 * j))
                j = j - 1
                i = i + 1
            argvals['%s%d' % (arg_pfx, vidx)] = word
            vidx = vidx + 1
        return argvals
    
    def constructActivePacket(self, fid, active_program, argvals, src="10.0.0.1", dst="10.0.0.2", preload=False, tcp_flags=None):
        bytecode = active_program[0]
        args = active_program[1]
        bulk_args = active_program[2]
        # flags = 0x0000 if len(args.keys()) == 0 else 0x8000
        flags = 0x8000
        # flags = (flags | 0x4000) if len(bulk_args.keys()) > 0 else flags
        flags = (flags | 0x0001) if preload else flags
        # print("%x" % flags)
        pkt = (
            Ether(type=0x83b2)/
            ActiveInitialHeader(fid=fid, flags=flags)
        )
        kwargs = {
            'data_0'    : 0,
            'data_1'    : 0,
            'data_2'    : 0,
            'data_3'    : 0
        }
        for arg in argvals:
            if arg in kwargs:
                kwargs[arg] = argvals[arg]
        """if len(args.keys()) > 0:
            for didx in args:
                kwargs['data_%d' % didx] = argvals[args[didx]]"""
        pkt = pkt / ActiveArguments(**kwargs)
        if len(bulk_args.keys()) > 0:
            kwargs_bulk = {
                'data_0'    : 0,
                'data_1'    : 0,
                'data_2'    : 0,
                'data_3'    : 0,
                'data_4'    : 0,
                'data_5'    : 0,
                'data_6'    : 0,
                'data_7'    : 0,
                'data_8'    : 0,
                'data_9'    : 0,
                'data_10'    : 0,
                'data_11'    : 0,
                'data_12'    : 0,
                'data_13'    : 0,
                'data_14'    : 0,
                'data_15'    : 0,
                'data_16'    : 0,
                'data_17'    : 0
            }
            for argname in bulk_args:
                kwargs_bulk['data_%d' % bulk_args[argname]] = argvals[argname]
            pkt = pkt / ActiveData(**kwargs_bulk)
        last_opcode = None
        for i in range(0, len(bytecode)):
            last_opcode = bytecode[i]['opcode']
            pkt = pkt / ActiveInstruction(opcode=bytecode[i]['opcode'], goto=bytecode[i]['goto'])
        if last_opcode != 0:
            pkt = pkt / ActiveInstruction(opcode=0)
        pkt = pkt / IP(src=src, dst=dst, proto=0x06)
        if tcp_flags is None:
            pkt = pkt / TCP()
        else:
            pkt = pkt / TCP(flags=tcp_flags)
        return pkt