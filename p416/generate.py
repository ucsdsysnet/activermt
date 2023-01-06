#!/usr/bin/python3

ANNOTATION_STAGE_ID         = '<stage-id>'
ANNOTATION_INSTRUCTION_ID   = '<instruction-id>'
ANNOTATION_ACTIONS          = '<generated-actions>'
ANNOTATION_ACTIONDEFS       = '<generated-actions-defs>'
ANNOTATION_TABLES           = '<generated-tables>'
ANNOTATION_MALLOC           = '<generated-malloc>'
ANNOTATION_CTRLFLOW         = '<generated-ctrlflow>'
ANNOTATION_MEMORY           = '<register-defs>'
ANNOTATION_POLY_COEFF       = '<poly-param-coeff>'
ANNOTATION_POLY_REVERSED    = '<poly-param-reversed>'
ANNOTATION_POLY_INIT        = '<poly-param-init>'
ANNOTATION_POLY_XOR         = '<poly-param-xor>'
ANNOTATION_HASHDEFS         = '<hash-defs>'
ANNOTATION_INSTRCOUNT       = '<generated-count-instr>'

class ActiveP4Generator:

    def __init__(self, truncate=False):
        self.truncate = truncate
        self.paths = {
            'actions'       : 'templates/actions.p4',
            'common-actions': 'templates/actions.common.p4',
            'data-actions'  : 'templates/actions.data.p4',
            'instruction'   : 'templates/instruction.p4',
            'malloc'        : 'templates/malloc.p4',
            'p1-instruction': 'templates/instruction.p1.p4',
            'memory'        : 'templates/memory.p4',
            'hashing'       : 'templates/hashing.p4',
            'ingress'       : 'templates/control.ingress.p4',
            'egress'        : 'templates/control.egress.p4'
        }
        self.crc_16_params = {
            'crc_16'        : ('0x18005', 'true', '0x0000', '0x0000')
        }
        self.registers = ('mar', 'mbr', 'mbr2')
        self.readonly = ('mar', 'mbr2')
        self.num_data = 4

    def getActionDefinitions(self, code):
        actions = []
        for line in code:
            if line.startswith('action'):
                tokens = line.split(' ')
                action = tokens[1]
                action = action[:action.index('(')]
                actions.append(action)
        return actions

    def getStagewiseActions(self, stage_id, offset=0):
        p4code = None
        with open(self.paths['actions']) as f:
            template = f.read()
            instruction_id = stage_id
            data_id = stage_id + offset
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_INSTRUCTION_ID, str(instruction_id)).replace('<data-id>', str(data_id))
            f.close()
        actions = self.getActionDefinitions(p4code.splitlines())
        return (p4code, actions)

    def getCommonActions(self):
        p4code = []
        with open(self.paths['common-actions']) as f:
            actions_code = f.read()
            p4code.append(actions_code)
            f.close()
        with open(self.paths['data-actions']) as f:
            template = f.read()
            rw_templates = template.split("}\n\n")
            for i in range(0, len(rw_templates) - 1):
                rw_templates[i] += "}"
            for i in range(0, len(self.registers)):
                reg = self.registers[i]
                for j in range(0, self.num_data):
                    data = "data_%d" % j
                    p4code.append(rw_templates[0].replace('<reg>', reg).replace('<data>', data).replace('<data-id>', str(j)))
                    if reg not in self.readonly:
                        p4code.append(rw_templates[1].replace('<reg>', reg).replace('<data>', data).replace('<data-id>', str(j)))
            if len(rw_templates) > 2:
                for j in range(0, self.num_data):
                    data = "data_%d" % j
                    p4code.append(rw_templates[2].replace('<data>', data).replace('<data-id>', str(j)))
            f.close()
        p4code = "\r\n".join(p4code)
        actions = self.getActionDefinitions(p4code.splitlines())
        return (p4code, actions)

    def getGeneratedTable(self, stage_id, offset=0):
        p4code = None
        actions = []
        gen = self.getCommonActions()
        actions = actions + gen[1]
        gen = self.getStagewiseActions(stage_id, offset)
        actions = actions + gen[1]
        p4code_actions = gen[0]
        with open(self.paths['instruction']) as f:
            template = f.read()
            instruction_id = stage_id
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_INSTRUCTION_ID, str(instruction_id)).replace(ANNOTATION_ACTIONS, "\n\t\t".join([ x + ';' for x in actions ]))
            f.close()
        lines = p4code.splitlines()
        tables = []
        for line in lines:
            if line.startswith('table'):
                tokens = line.split(' ')
                tables.append(tokens[1])
        return (p4code, tables, p4code_actions)

    def getGeneratedMalloc(self, stage_id):
        p4code = None
        with open(self.paths['malloc']) as f:
            template = f.read()
            instruction_id = stage_id
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_INSTRUCTION_ID, str(instruction_id))
            f.close()
        lines = p4code.splitlines()
        tables = []
        for line in lines:
            if line.startswith('table'):
                tokens = line.split(' ')
                tables.append(tokens[1])
        return (p4code, tables)

    def getGeneratedRegister(self, stage_id, offset):
        p4code = None
        with open(self.paths['memory']) as f:
            template = f.read()
            data_id = stage_id + offset
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace('<data-id>', str(data_id))
            f.close()
        return p4code

    def getGeneratedHashing(self, stage_id, hash_algo):
        p4code = None
        with open(self.paths['hashing']) as f:
            template = f.read()
            hash_params = self.crc_16_params[hash_algo]
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_POLY_COEFF, hash_params[0]).replace(ANNOTATION_POLY_REVERSED, hash_params[1]).replace(ANNOTATION_POLY_INIT, hash_params[2]).replace(ANNOTATION_POLY_XOR, hash_params[3])
            f.close()
        return p4code

    def getGeneratedControl(self, eg_ig, num_stages, offset=0):
        p4code = None
        with open(self.paths[eg_ig]) as f:
            template = f.read()
            gen_common_actions = self.getCommonActions()
            table_code = ""
            action_code = gen_common_actions[0] + "\r\n"
            register_code = ""
            hashing_code = ""
            table_names = []
            malloc_tables = []
            hash_idx = 0
            hash_algos = list(self.crc_16_params.keys())
            for i in range(0, num_stages):
                instr_id = i
                tabledefs = self.getGeneratedTable(i, offset)
                mallocdefs = self.getGeneratedMalloc(i) if offset == 0 else ("", [])
                registerdefs = self.getGeneratedRegister(i, offset)
                hash_algo = hash_algos[hash_idx]
                hash_idx = (hash_idx + 1) % len(hash_algos)
                hashdefs = self.getGeneratedHashing(i, hash_algo)
                table_code = table_code + "\n\n" + tabledefs[0] + "\n\n" + mallocdefs[0]
                action_code = action_code + tabledefs[2]
                register_code = register_code + "\n\n" + registerdefs
                hashing_code = hashing_code + "\n\n" + hashdefs
                if self.truncate:
                    set_tables = " ".join([ "%s.apply();" % x for x in tabledefs[1] ])
                    table_names.append('if(hdr.instr[%d].isValid()) { %s hdr.instr[%d].setInvalid(); }' % (i, set_tables, i))
                    #table_names.append('if(hdr.meta.mbr == 0) hdr.meta.zero = true;')
                else:
                    table_names = table_names + [('if(hdr.instr[%d].isValid()) { %s.apply(); }' % (i, x)) for x in tabledefs[1]]
                malloc_tables.append(" ".join([ "%s.apply();" % x for x in mallocdefs[1] ]))
                #table_names = table_names + [('if(hdr.instr[%d].isValid()) { meta.instr_count = meta.instr_count + 4; %s.apply(); hdr.instr[%d].flags = 1; }' % (i, x, i)) for x in tabledefs[1]]
            p4code = template.replace(ANNOTATION_ACTIONDEFS, action_code).replace(ANNOTATION_TABLES, table_code).replace(ANNOTATION_CTRLFLOW, "\n\t\t".join(table_names)).replace(ANNOTATION_MALLOC, "\n\t\t".join(malloc_tables)).replace(ANNOTATION_MEMORY, register_code).replace(ANNOTATION_HASHDEFS, hashing_code)
            f.close()
        return p4code

generator = ActiveP4Generator(truncate=True)

with open('ingress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('ingress', 10))
    f.close()

with open('egress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('egress', 10, 10))
    f.close()