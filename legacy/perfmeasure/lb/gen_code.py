#!/usr/bin/python

import os
import json

class Instruction:
    def __init__(self, instr=None, arg=0, goto=0):
        self.instr = instr
        self.arg = arg
        self.goto = goto

OPCODES = json.loads(open('../../opcodes.json').read(), encoding='utf-8')

# WRITE PROGRAM HERE

program_sender = [
    Instruction(instr='HASHID'),
    Instruction(instr='MBR_LOAD', arg=255),
    Instruction(instr='CMEM_WRITE'),
    Instruction(instr='CMEM_WRITE'),
    Instruction(instr='CMEM_WRITE'),
    Instruction(instr='CMEM_WRITE'),
    Instruction(instr='C_ENABLE_EXEC', goto=2),
    Instruction(instr='ACC_LOAD'),
    Instruction(instr='RTS', goto=2),
    Instruction(instr='RETURN'),
    Instruction(instr='EOF')
]

program_gc = [
    Instruction(instr='HASHID'),
    Instruction(instr='NOP'),
    Instruction(instr='MEM_RST'),
    Instruction(instr='MEM_RST'),
    Instruction(instr='MEM_RST'),
    Instruction(instr='MEM_RST'),
    Instruction(instr='RETURN'),
    Instruction(),
    Instruction(instr='EOF')
]

"""program = [
    Instruction(instr='NOP'),
    Instruction(instr='RETURN'),
    Instruction(),
    Instruction(instr='EOF')
]"""

# PROGRAM END

code = []
for i in program_sender:
    if i.instr is None:
        code.append("0,0,0")
    else:
        code.append("%d,%d,%d" % (OPCODES[i.instr], i.arg, i.goto))
with open("sender_program.txt", "w") as out:
    out.write("\n".join(code))
    out.close()

code = []
for i in program_gc:
    if i.instr is None:
        code.append("0,0,0")
    else:
        code.append("%d,%d,%d" % (OPCODES[i.instr], i.arg, i.goto))
with open("gc_program.txt", "w") as out:
    out.write("\n".join(code))
    out.close()