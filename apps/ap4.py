#!/usr/bin/python

import os
import sys
import json

class ActiveInstruction:
    def __init__(self, opcode=0, arg=0, goto=0):
        self.opcode = opcode
        self.arg = arg
        self.goto = goto

    def getBytes(self):
        instr = ( bytes(chr(self.goto)) + bytes(chr(self.opcode)) + bytes(chr(self.arg >> 8)) + bytes(chr(self.arg)) )
        return instr

class ActiveProgram:
    def __init__(self, program):
        self.OPCODES = {}
        opcodeList = open('../bfrt/opcode_action_mapping.csv').read().strip().splitlines()
        for opcode in range(0, len(opcodeList)):
            m = opcodeList[opcode].split(',')
            pnemonic = m[0]
            self.OPCODES[pnemonic] = opcode
        self.program = []
        self.args = {}
        self.labels = {}
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
                        self.args[argname] = []    
                    self.args[argname].append(len(program) - i - 1)
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
            self.program.append(ActiveInstruction(opcode=self.OPCODES[opcode], arg=0, goto=label))
        self.program.reverse()
        self.program.append(ActiveInstruction(opcode=self.OPCODES['EOF'], arg=0, goto=0))

    def getByteCode(self):
        if len(self.program) < 1:
            return bytes('')
        bytecode = self.program[0].getBytes()
        for i in range(1, len(self.program)):
            bytecode = bytecode + self.program[i].getBytes()
        return bytecode
    
    def getArgumentMap(self):
        args = []
        for arg in self.args:
            for idx in self.args[arg]:
                args.append((arg, idx))
        return args

if len(sys.argv) < 2:
    print('Usage: %s <program.ap4>' % sys.argv[0])
    exit(0)

with open(sys.argv[1]) as f:
    rows = f.read().strip().splitlines()
    program = [ x.split(',') for x in rows ]
    ap = ActiveProgram(program)
    with open(sys.argv[1].replace('.ap4', '.apo'), 'w') as out:
        out.write(ap.getByteCode())
        out.close()
    with open(sys.argv[1].replace('.ap4', '.args.csv'), 'w') as out:
        out.write("\n".join([ ",".join([str(y) for y in x]) for x in ap.getArgumentMap() ]))
        out.close()
    f.close()