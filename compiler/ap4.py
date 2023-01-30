#!/usr/bin/python

import os
import re
import sys
import json

class ActiveIH:

    ACTIVEP4_SIG = 0x12345678

    def __init__(self):
        self.fid = 1

class ActiveInstruction:
    def __init__(self, opcode=0, goto=0):
        self.opcode = opcode
        self.goto = goto

    def getBytes(self):
        instr = ( bytes(chr(self.goto)) + bytes(chr(self.opcode)) )
        return instr

    def printInstruction(self, mnemonics=None, idx=None):
        opname = mnemonics[self.opcode] if mnemonics is not None else "OPCODE"
        if idx is None:
            print("%02X (%d)\t[%d]\t%s" % (self.opcode, self.opcode, self.goto, opname))
        else:
            print("%d.\t%02X (%d)\t[%d]\t%s" % (idx, self.opcode, self.opcode, self.goto, opname))

class ActiveProgram:
    def __init__(self, program, optimize=True):
        self.max_args = 4
        self.opt_data = False
        self.IG_ONLY = ['SET_DST', 'RTS', 'CRTS']
        self.OPCODES = {}
        self.MNEMONICS = {}
        opcodeList = open(os.path.join(os.environ['ACTIVEP4_SRC'], 'config', 'opcode_action_mapping.csv')).read().strip().splitlines()
        for opcode in range(0, len(opcodeList)):
            m = opcodeList[opcode].split(',')
            pnemonic = m[0]
            self.OPCODES[pnemonic] = opcode
            self.MNEMONICS[opcode] = pnemonic
        self.LOAD_INSTR = [ 'MAR_LOAD', 'MBR_LOAD', 'MBR2_LOAD' ]
        self.regex_data = re.compile('DATA_([0-9])')
        self.reg_load = {
            'MAR'   : None,
            'MBR'   : None,
            'MBR2'  : None
        }
        self.program = []
        self.args = {}
        self.labels = {}
        self.num_data = 0
        self.data_idx = []
        self.memidx = []
        self.memlim = []
        self.iglim = -1
        self.referenced_regs = set()
        for i in range(0, len(program)):
            opcode = program[i][0]
            if 'MEM' in opcode:
                self.memidx.append(i)
            elif opcode in self.LOAD_INSTR:
                reg = opcode.split('_')[0]
                arg = program[i][1] if len(program[i]) > 1 else None
                referenced = reg in self.referenced_regs
                self.reg_load[reg] = (i, arg, referenced)
            if program[i][0] in self.IG_ONLY:
                self.iglim = i if i > self.iglim else self.iglim
            for reg in self.reg_load:
                if reg in opcode:
                    self.referenced_regs.add(reg)
        program.reverse()
        memIdx = None
        buffer = []
        for i in range(0, len(program)):
            opcode = program[i][0]
            # if '_LOAD_' in opcode:
            #     data_reg = re.search('DATA_([0-9])', opcode).group(1)
            #     didx = int(data_reg)
            #     if didx not in self.data_idx:
            #         self.data_idx.append(didx)
            if 'MEM' in opcode:
                memIdx = len(program) - i - 1
            elif 'ADDR' in opcode and memIdx is not None:
                opcode = "%s_%d" % (opcode, memIdx)
            program[i][0] = opcode
        for i in range(0, len(program)):
            opcode = program[i][0]
            param_1 = program[i][1] if len(program[i]) > 1 else None
            param_2 = program[i][2] if len(program[i]) > 2 else None
            label = 0
            if param_1 is not None:
                if param_1[0] == ':':
                    self.labels[param_1] = 1
                    label = 1
                elif param_1[0] == '@':
                    label = self.labels[':%s' % param_1[1:]]
                elif param_1[0] == '$':
                    argname = param_1[1:]
                    # if argname not in self.args:
                    #     self.args[argname] = {
                    #         'idx'   : [],
                    #         'didx'  : None,
                    #         'bulk'  : False
                    #     }
                    # if opcode in self.LOAD_INSTR:
                    #     if self.args[argname]['didx'] is None:
                    #         while self.num_data in self.data_idx:
                    #             self.num_data = self.num_data + 1
                    #         self.args[argname]['didx'] = self.num_data
                    #         self.data_idx.append(self.num_data)
                    #     # opcode = '%s_DATA_%d' % (opcode, self.args[argname]['didx'])
                    #     opcode = '%s_DATA_%d' % (opcode, self.LOAD_INSTR.index(opcode))
                    # elif '_BULK_WRITE' in opcode:
                    #     self.args[argname]['bulk'] = True
                    #     self.args[argname]['didx'] = 0
                    # self.args[argname]['idx'].append(len(program) - i - 1)
            if param_2 is not None:    
                if param_2[0] == ':':
                    self.labels[param_2] = 1
                    label = 1
                elif param_2[0] == '@':
                    label = self.labels[':%s' % param_2[1:]]
                elif param_2[0] == '$':
                    argname = param_2[1:]
                    if argname not in self.args:
                        self.args[argname] = []    
                    self.args[argname].append(len(program) - i - 1)
            # print(program[i])
            buffer.append(ActiveInstruction(opcode=self.OPCODES[opcode], goto=label))
        buffer.reverse()
        buffer.append(ActiveInstruction(opcode=self.OPCODES['EOF'], goto=0))
        # optimize program
        if optimize:
            self.memidx = []
            idx = 0
            for instr in buffer:
                pnemonic = self.MNEMONICS[instr.opcode]
                reg = pnemonic.split('_LOAD')[0] if '_LOAD' in pnemonic else pnemonic
                if reg in self.reg_load and not self.reg_load[reg][2]:
                    print("[Optimization] Skipping %s ..." % pnemonic)
                    continue
                if 'MEM' in pnemonic:
                    self.memidx.append(idx)
                self.program.append(instr)
                idx += 1
        else:
            self.program = buffer

    def compileToTarget(self, num_stages_ig, num_stages_eg):
        if len(self.memidx) == 0:
            return
        # total number of memory accesses cannot exceed the number of stages.
        assert(len(self.memidx) <= (num_stages_ig + num_stages_eg))
        # check for conflicting memory accesses.
        # swMemIdx = [ ( x if x < num_stages_ig else num_stages_ig + (x - num_stages_ig) % num_stages_eg ) for x in self.memidx ]
        memMap = {}
        for i in range(0, len(self.program)):
            pnemonic = self.MNEMONICS[self.program[i].opcode]
            if 'MEM' not in pnemonic:
                continue
            swIdx = i if i < num_stages_ig else num_stages_ig + (i - num_stages_ig) % num_stages_eg
            if swIdx not in memMap:
                memMap[swIdx] = []
            memMap[swIdx].append(i)
        for memIdx in memMap:
            if len(memMap[memIdx]) > 1:
                print("WARN: Conflicting memory access for stage %d (%s)" % (memIdx, ",".join([ str(x) for x in memMap[memIdx] ])))

    def getByteCode(self):
        if len(self.program) < 1:
            return bytes('')
        bytecode = self.program[0].getBytes()
        for i in range(1, len(self.program)):
            bytecode = bytecode + self.program[i].getBytes()
        return bytecode

    def printProgram(self):
        print("#\tOPCODE\tFLAGS\tMNEMONIC")
        for i in range(0, len(self.program)):
            self.program[i].printInstruction(mnemonics=self.MNEMONICS, idx=i)
    
    def getArgumentMap(self):
        args = []
        for arg in self.args:
            for idx in self.args[arg]['idx']:
                is_bulk = 1 if self.args[arg]['bulk'] else 0
                args.append((arg, idx, self.args[arg]['didx'], is_bulk))
        return args

    def getMemoryAccessIndices(self):
        return self.memidx

if len(sys.argv) < 2:
    print('Usage: %s <program.ap4> [num_ingress_stages=10] [num_egress_stages=10]' % sys.argv[0])
    exit(0)

num_stages_ig = int(sys.argv[2]) if len(sys.argv) > 2 else 10
num_stages_eg = int(sys.argv[3]) if len(sys.argv) > 3 else 10

with open(sys.argv[1]) as f:
    print("")
    rows = f.read().strip().splitlines()
    for i in range(0, len(rows)):
        idx = rows[i].find('//')
        if idx >= 0:
            rows[i] = rows[i][0:idx].strip()
    program = [ x.split(',') for x in rows ]
    ap = ActiveProgram(program)
    ap.compileToTarget(num_stages_ig, num_stages_eg)
    print("")
    ap.printProgram()
    with open(sys.argv[1].replace('.ap4', '.apo'), 'w') as out:
        out.write(ap.getByteCode())
        out.close()
    with open(sys.argv[1].replace('.ap4', '.args.csv'), 'w') as out:
        out.write("\n".join([ ",".join([str(y) for y in x]) for x in ap.getArgumentMap() ]))
        out.close()
    with open(sys.argv[1].replace('.ap4', '.memidx.csv'), 'w') as out:
        memDef = ",".join([str(x) for x in ap.getMemoryAccessIndices()])
        memDef += "\n" + str(ap.iglim) + "\n"
        out.write(memDef)
        out.close()
    with open(sys.argv[1].replace('.ap4', '.regloads.csv'), 'w') as out:
        data = []
        for x in ap.reg_load:
            if ap.reg_load[x] is not None:
                data.append("%s,%s" % (x, ap.reg_load[x][1]))
        out.write("\n".join(data))
        out.close()
    f.close()