import os
from scapy.packet import Packet
from scapy.fields import *

class ActiveIH(Packet):
    name = "ActiveIH"
    fields_desc = [
        IntField("ACTIVEP4", 0x12345678),
        ShortField("flags", 0),
        ShortField("fid", 0),
        ShortField("seq", 0),
        ShortField("acc", 0),
        ShortField("acc2", 0),
        ShortField("data", 0),
        ShortField("data2", 0),
        ShortField("res", 0)
    ]

class ActiveInstruction(Packet):
    name = "ActiveInstruction"
    fields_desc = [
        ByteField("goto", 0), # also has flags
        ByteField("opcode", 0),
        ShortField("arg", 0)
    ]

class ActiveApplication:

    def __init__(self):
        self.fid = 1
        self.seq = 0
        self.mask = 0xFFFF
        self.offset = 0x0
        self.activesrc = {}

    def filterActiveProgram(self, data, truncationEnabled=False):
        ACTIVEP4_IH_LEN = 20
        ACTIVEP4_EOF = 0x0
        flag_complete = data[4] & 0x01
        if self.DEBUG:
            print(data)
        if (truncationEnabled and flag_complete == 1) or len(data) < ACTIVEP4_IH_LEN:
            if self.DEBUG:
                print("Active program instructions not present.")
            return (data[:ACTIVEP4_IH_LEN], data[ACTIVEP4_IH_LEN:])
        idx = ACTIVEP4_IH_LEN + 1
        opcode = 0x1
        while opcode != ACTIVEP4_EOF:
            opcode = data[idx]
            idx = idx + 4
        return (data[:idx - 1], data[idx - 1:])

    def buildActiveProgram(self, program, args):
        if program not in self.activesrc:
            return None
        if self.activesrc[program]['code'] == None:
            basepath = os.path.join(os.environ['ACTIVEP4_SRC'], 'apps', 'activep4', self.activesrc[program]['dir'])
            with open(os.path.join(basepath, self.activesrc[program]['file'][0])) as f:
                self.activesrc[program]['code'] = bytes(f.read(), 'utf-8')
                f.close()
            with open(os.path.join(basepath, self.activesrc[program]['file'][1])) as f:
                args = f.read().strip().splitlines()
                for a in args:
                    arg = a.split(',')
                    argname = arg[0]
                    argidx = int(arg[1])
                    if argname not in args:
                        self.activesrc[program]['args'][argname] = []
                    self.activesrc[program]['args'][argname].append(argidx)
                f.close()
        activecode = copy.deepcopy(self.activesrc[program]['code'])
        for a in args:
            arg = a[0]
            val = a[1]
            if arg in self.activesrc[program]['args']:
                arr_idx = self.activesrc[program]['args'][arg]
                for idx in arr_idx:
                    activecode[idx * 4 + 2] = bytes(chr(val >> 8))
                    activecode[idx * 4 + 3] = bytes(chr(val))
        self.seq = self.seq + 1
        pktbytes = bytes(ActiveIH(fid=self.fid, seq=self.seq)) + activecode
        if self.DEBUG:
            print(activecode)
        return pktbytes