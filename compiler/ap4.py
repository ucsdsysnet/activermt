#!/usr/bin/python

import os
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

    def printInstruction(self, mnemonics=None):
        opname = mnemonics[self.opcode] if mnemonics is not None else "OPCODE"
        print("%d\t[%d]\t%s" % (self.opcode, self.goto, opname))

class ActiveProgram:
    def __init__(self, program):
        self.max_args = 5
        self.opt_data = False
        self.OPCODES = {}
        self.MNEMONICS = {}
        opcodeList = open(os.path.join(os.environ['ACTIVEP4_SRC'], 'config', 'opcode_action_mapping.csv')).read().strip().splitlines()
        for opcode in range(0, len(opcodeList)):
            m = opcodeList[opcode].split(',')
            pnemonic = m[0]
            self.OPCODES[pnemonic] = opcode
            self.MNEMONICS[opcode] = pnemonic
        self.program = []
        self.args = {}
        self.labels = {}
        self.num_data = 0
        program.reverse()
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
                    if argname not in self.args:
                        self.args[argname] = {
                            'idx'   : [],
                            'didx'  : None,
                            'bulk'  : False
                        }
                        if '_LOAD' in opcode:
                            self.args[argname]['didx'] = self.num_data
                            opcode = '%s_DATA_%d' % (opcode, self.num_data)
                            self.num_data = self.num_data + 1
                        elif '_BULK_WRITE' in opcode:
                            self.args[argname]['bulk'] = True
                            self.args[argname]['didx'] = 0
                    self.args[argname]['idx'].append(len(program) - i - 1)
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
            self.program.append(ActiveInstruction(opcode=self.OPCODES[opcode], goto=label))
        self.program.reverse()
        self.program.append(ActiveInstruction(opcode=self.OPCODES['EOF'], goto=0))

    def getByteCode(self):
        if len(self.program) < 1:
            return bytes('')
        bytecode = self.program[0].getBytes()
        for i in range(1, len(self.program)):
            bytecode = bytecode + self.program[i].getBytes()
        return bytecode

    def printProgram(self):
        print("OPCODE\tFLAGS\tMNEMONIC")
        for i in range(0, len(self.program)):
            self.program[i].printInstruction(mnemonics=self.MNEMONICS)
    
    def getArgumentMap(self):
        args = []
        for arg in self.args:
            for idx in self.args[arg]['idx']:
                is_bulk = 1 if self.args[arg]['bulk'] else 0
                args.append((arg, idx, self.args[arg]['didx'], is_bulk))
        return args

if len(sys.argv) < 2:
    print('Usage: %s <program.ap4>' % sys.argv[0])
    exit(0)

with open(sys.argv[1]) as f:
    rows = f.read().strip().splitlines()
    program = [ x.split(',') for x in rows ]
    ap = ActiveProgram(program)
    ap.printProgram()
    with open(sys.argv[1].replace('.ap4', '.apo'), 'w') as out:
        out.write(ap.getByteCode())
        out.close()
    with open(sys.argv[1].replace('.ap4', '.args.csv'), 'w') as out:
        out.write("\n".join([ ",".join([str(y) for y in x]) for x in ap.getArgumentMap() ]))
        out.close()
    f.close()