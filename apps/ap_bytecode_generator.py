#!/usr/bin/python

import os
import json

class ActiveProgram:
    def __init__(self, opcode=0, arg=0, goto=0):
        self.opcode = opcode
        self.arg = arg
        self.goto = goto

class Generator:
    def __init__(self):
        self.OPCODES = {}
        opcodeList = open('../config/opcodes.csv').read().strip().splitlines()
        for id in range(0, len(opcodeList)):
            self.OPCODES[ opcodeList[id] ] = id + 1

    def generate(self, program, outFile):
        bytecode = []
        for i in range(0, len(program)):
            bytecode.append( "%d,%d,%d" % (program[i].goto, program[i].opcode, program[i].arg) )
        with open(outFile, 'w') as out:
            out.write("\n".join(bytecode))
            out.close()

# //////////////////////// PROGRAMS \\\\\\\\\\\\\\\\\\\\\\\\\

class CacheProgramsGenerator(Generator):

    def generateRequestProgram(self, outFile):
        program = [
            # compute mem_idx
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),
            ActiveProgram(opcode=self.OPCODES['HASHMBR']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),
            # check if key/object exists
            ActiveProgram(opcode=self.OPCODES['MEM_READ']),
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=8193), 
            # if it exists,
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2),
            ActiveProgram(opcode=self.OPCODES['MEM_READ']), # load the value
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD']),
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW']), # increment access counter
            ActiveProgram(opcode=self.OPCODES['RTS'], goto=2),

            # if not,
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),
            ActiveProgram(opcode=self.OPCODES['HASHMBR']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW']), # iter 1
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2']), 
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),
            ActiveProgram(opcode=self.OPCODES['HASHMBR']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),

            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW']), # iter 2
            ActiveProgram(opcode=self.OPCODES['REVMIN']),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),
            ActiveProgram(opcode=self.OPCODES['HASHMBR']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW']), # iter 3
            ActiveProgram(opcode=self.OPCODES['REVMIN']),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),

            ActiveProgram(opcode=self.OPCODES['HASHMBR']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW']), # iter 4

            ActiveProgram(opcode=self.OPCODES['REVMIN']),
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD']),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=2), # load hot-item frequency threshold
            ActiveProgram(opcode=self.OPCODES['MIN']),
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=2), # frequency crossed threshold
            ActiveProgram(opcode=self.OPCODES['MARK_IF']),
            ActiveProgram(opcode=self.OPCODES['RETURN']),

            ActiveProgram(),
            ActiveProgram(opcode=self.OPCODES['EOF'])
        ]
        self.generate(program, outFile)

    def generateResponseProgram(self, outFile):
        program = [
            # compute index
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),
            ActiveProgram(opcode=self.OPCODES['HASHMBR']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),
            # attempt reading existing object
            ActiveProgram(opcode=self.OPCODES['MEM_READ']),
            # if it does exist,
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=100),
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2']),
            ActiveProgram(opcode=self.OPCODES['MEM_READ']),
            ActiveProgram(opcode=self.OPCODES['REVMIN']),
            
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_MBR2']),
            ActiveProgram(opcode=self.OPCODES['CRET'], goto=2),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE']),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=1234),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE']),
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=300),
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE']),
            ActiveProgram(opcode=self.OPCODES['RETURN']),

            ActiveProgram(),
            ActiveProgram(opcode=self.OPCODES['EOF'])
        ]
        self.generate(program, outFile)

class SLBProgramsGenerator(Generator):

    def generateRequestProgram(self, outFile):
        program = [
            ActiveProgram(opcode=self.OPCODES['LOAD_5TUPLE']),
            ActiveProgram(opcode=self.OPCODES['HASH_GENERIC']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191),
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0), # get address of conntable
            ActiveProgram(opcode=self.OPCODES['MEM_READ']),
            ActiveProgram(opcode=self.OPCODES['SET_PORT']), # just forward if already present in table
            ActiveProgram(opcode=self.OPCODES['CRET']),
            ActiveProgram(opcode=self.OPCODES['MEM_READ']), # get base location of DIP pool
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2']),
            ActiveProgram(opcode=self.OPCODES['MEM_READ']), # get size of DIP pool
            ActiveProgram(opcode=self.OPCODES['HASH_GENERIC']),

            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR_MBR']),
            ActiveProgram(opcode=self.OPCODES['COPY_MBR2_MBR']), 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD_MBR']), # choose one server from DIP pool
            ActiveProgram(opcode=self.OPCODES['MEM_READ']), # mbr now has the port of the conn
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['NOP']),

            ActiveProgram(opcode=self.OPCODES['NOP']),
            ActiveProgram(opcode=self.OPCODES['HASH_GENERIC']),
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191),
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0),
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE']), # store port in conntable
            ActiveProgram(opcode=self.OPCODES['SET_PORT']),
            ActiveProgram(opcode=self.OPCODES['RETURN'])
        ]
        self.generate(program, outFile)

apgen = CacheProgramsGenerator()
apgen.generateRequestProgram('cache_read_req.csv')
apgen.generateResponseProgram('cache_read_response.csv')

apgen2 = SLBProgramsGenerator()
apgen2.generateRequestProgram('slb_src.csv')