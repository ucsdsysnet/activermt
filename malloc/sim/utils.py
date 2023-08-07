import os
import sys

class Util:

    INSTR_SET_PATH = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', 'config', 'opcode_action_mapping.csv')
    IG_ONLY_INSTR = ('SET_DST', 'RTS', 'CRTS')
    MEM_PFX = 'MEM_'

    def __init__(self):
        self.instruction_set = None
        self.programs = {}

    def buildConstraints(self, program_name, demand):
        assert(program_name in self.programs)
        bytecode = self.programs[program_name]
        constraints = {
            'length'    : len(bytecode),
            'iglim'     : -1,
            'memidx'    : [],
            'mindemand' : []
        }
        igLim = -1
        for i in range(len(bytecode)):
            pnemonic = self.instruction_set[bytecode[i]['opcode']][0]
            if pnemonic in self.IG_ONLY_INSTR:
                igLim = i
            if pnemonic.startswith(self.MEM_PFX):
                constraints['memidx'].append(i)
        constraints['iglim'] = igLim
        constraints['mindemand'] = [demand] * len(constraints['memidx'])
        return constraints

    def readInstructionSet(self):
        assert(os.path.exists(self.INSTR_SET_PATH))
        if self.instruction_set is not None:
            return self.instruction_set
        with open(self.INSTR_SET_PATH, 'r') as f:
            opcode = 0
            self.instruction_set = {}
            for line in f.readlines():
                info = line.split(',')
                pnemonic = info[0].strip()
                action_id = info[1].strip()
                condition = None if len(info) < 3 else (True if info[2] == '1' else False)
                self.instruction_set[opcode] = (pnemonic, action_id, condition)
                opcode += 1
            f.close()
        assert(self.instruction_set is not None)
        return self.instruction_set

    def readProgram(self, program_path, program_name=None):
        assert(os.path.exists(program_path))
        if program_name is not None and program_name in self.programs:
            return self.programs[program_name]
        bytecode = []
        with open(program_path, 'rb') as f:
            program = list(f.read())
            i = 0
            while i < len(program):
                bytecode.append({
                    'opcode'    : program[i + 1],
                    'goto'      : program[i]
                })
                i += 2
            f.close()
        assert(bytecode is not None)
        if program_name is not None:
            self.programs[program_name] = bytecode
        return bytecode
