import os
import re
import json

class ActiveInstruction:

    def __init__(self, opcode=0, goto=0):
        self.opcode = opcode
        self.goto = goto

    def getBytes(self):
        instr = ( bytes(chr(self.goto), encoding='utf-8') + bytes(chr(self.opcode), encoding='utf-8') )
        return instr

    def printInstruction(self, mnemonics=None, idx=None):
        opname = mnemonics[self.opcode] if mnemonics is not None else "OPCODE"
        if idx is None:
            print("%02X (%d)\t[%d]\t%s" % (self.opcode, self.opcode, self.goto, opname))
        else:
            print("%d.\t%02X (%d)\t[%d]\t%s" % (idx, self.opcode, self.opcode, self.goto, opname))

class ActiveProgram:

    def __init__(self, program, optimize=True):
        self.base_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..'))
        self.max_args = 4
        self.opt_data = False
        self.IG_ONLY = ['SET_DST', 'RTS', 'CRTS']
        self.OPCODES = {}
        self.MNEMONICS = {}
        opcodeList = open(os.path.join(self.base_dir, 'activermt', 'opcode_action_mapping.csv')).read().strip().splitlines()
        for opcode in range(0, len(opcodeList)):
            m = opcodeList[opcode].split(',')
            pnemonic = m[0]
            self.OPCODES[pnemonic] = opcode
            self.MNEMONICS[opcode] = pnemonic
        self.LOAD_INSTR = [ 'MAR_LOAD', 'MBR_LOAD', 'MBR2_LOAD' ]
        self.regex_data = re.compile('DATA_([0-9])')
        self.regex_register = re.compile('(MAR|MBR2|MBR)')
        self.reg_load = {}
        self.access_write = {
            'MAR'   : [ 'HASH' ],
            'MBR'   : [ 'MIN', 'MAX', 'LOAD_QDELAY', 'LOAD_QUEUE' ],
            'MBR2'  : [ 'REVMIN' ]
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
            program[i][0] = program[i][0].strip()
            opcode = program[i][0]
            reg = self.regex_register.findall(opcode)
            reg = reg[0] if len(reg) > 0 else None
            if reg is None:
                for r in self.access_write:
                    if opcode in self.access_write[r]:
                        reg = r
                        break
            if 'MEM' in opcode:
                self.memidx.append(i)
            elif reg is not None:
                if 'LOAD' in opcode and reg not in self.reg_load:
                    arg = program[i][1] if len(program[i]) > 1 else None
                    referenced = reg in self.referenced_regs
                    self.reg_load[reg] = (i, arg, referenced)
                self.referenced_regs.add(reg)
            if program[i][0] in self.IG_ONLY:
                self.iglim = i if i > self.iglim else self.iglim
        program.reverse()
        buffer = []
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
            skipped = set()
            for instr in buffer:
                pnemonic = self.MNEMONICS[instr.opcode]
                reg = pnemonic.split('_LOAD')[0] if '_LOAD' in pnemonic else pnemonic
                if reg in self.reg_load and not self.reg_load[reg][2] and reg not in skipped:
                    skipped.add(reg)
                    print("[Optimization] Skipping %s ..." % pnemonic)
                    continue
                if 'MEM' in pnemonic:
                    self.memidx.append(idx)
                self.program.append(instr)
                idx += 1
        else:
            self.program = buffer
        memIdx = None
        for k in range(0, len(self.program)):
            i = len(self.program) - k - 1
            opcode = self.MNEMONICS[self.program[i].opcode]
            if 'MEM' in opcode:
                memIdx = i
            elif 'ADDR' in opcode and memIdx is not None:
                opcode = "%s_%d" % (opcode, memIdx)
                self.program[i].opcode = self.OPCODES[opcode]

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
    
class AP4Source:

    NUM_STAGES_IG = 10
    NUM_STAGES_EG = 10

    def __init__(self, ap4Path):
        with open(ap4Path) as f:
            rows = f.read().strip().splitlines()
            for i in range(0, len(rows)):
                idx = rows[i].find('//')
                if idx >= 0:
                    rows[i] = rows[i][0:idx].strip()
            program = [ x.split(',') for x in rows ]
            self.program = ActiveProgram(program)
            self.program.compileToTarget(self.NUM_STAGES_IG, self.NUM_STAGES_EG)
            f.close()

    def getProgram(self):
        return self.program