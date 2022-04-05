#!/usr/bin/python

import os
import json

class Instruction:
    def __init__(self, instr=None, arg=0, goto=0):
        self.instr = instr
        self.arg = arg
        self.goto = goto

OPCODES = json.loads(open('../opcodes.json').read(), encoding='utf-8')

# WRITE PROGRAM HERE

programBasic = [
    Instruction(instr='MBR_LOAD', arg=1),
    Instruction(instr='MBR_ADD', arg=1),
    Instruction(instr='ACC_LOAD'),
    Instruction(instr='RETURN'),
    Instruction(),
    Instruction(instr='EOF')
]

programCacheRead = [
    Instruction(instr='MAR_LOAD', arg=8193),
    Instruction(instr='NOP'),
    Instruction(instr='MEM_READ'),
    Instruction(instr='CJUMPI', goto=2),
    Instruction(instr='ACC_LOAD'),
    Instruction(instr='RTS', goto=2),
    Instruction(instr='RETURN'),
    Instruction(),
    Instruction(instr='EOF')
]

programCacheWrite = [
    Instruction(instr='MAR_LOAD', arg=8193),
    Instruction(instr='MBR_LOAD', arg=11),
    Instruction(instr='MEM_WRITE'),
    Instruction(instr='ENABLE_EXEC'),
    Instruction(instr='RTS'),
    Instruction(instr='RETURN'),
    Instruction(),
    Instruction(instr='EOF')
]

programs = {
    'basic'         : programBasic,
    'cache_read'    : programCacheRead,
    'cache_write'   : programCacheWrite
}

# PROGRAM END

for pname in programs:
    program = programs[pname]
    code = []
    for i in program:
        if i.instr is None:
            code.append("0,0,0")
        else:
            code.append("%d,%d,%d" % (OPCODES[i.instr], i.arg, i.goto))
    with open("%s.txt" % pname, "w") as out:
        out.write("\n".join(code))
        out.close()