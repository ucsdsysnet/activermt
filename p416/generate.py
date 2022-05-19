#!/usr/bin/python3

ANNOTATION_STAGE_ID         = '<stage-id>'
ANNOTATION_INSTRUCTION_ID   = '<instruction-id>'
ANNOTATION_ACTIONS          = '<generated-actions>'
ANNOTATION_ACTIONDEFS       = '<generated-actions-defs>'
ANNOTATION_TABLES           = '<generated-tables>'
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
            'instruction'   : 'templates/instruction.p4',
            'memory'        : 'templates/memory.p4',
            'hashing'       : 'templates/hashing.p4',
            'ingress'       : 'templates/control.ingress.p4',
            'egress'        : 'templates/control.egress.p4'
        }
        self.crc_16_params = {
            'crc_16'        : ('0x18005', 'true', '0x0000', '0x0000')
        }

    def getGeneratedActions(self, stage_id):
        p4code = None
        actions = []
        with open(self.paths['actions']) as f:
            template = f.read()
            instruction_id = stage_id
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_INSTRUCTION_ID, str(instruction_id))
            f.close()
        lines = p4code.splitlines()
        for line in lines:
            if line.startswith('action'):
                tokens = line.split(' ')
                action = tokens[1]
                action = action[:action.index('(')]
                actions.append(action)
        return (p4code, actions)

    def getGeneratedTable(self, stage_id):
        p4code = None
        p4code_actions = self.getGeneratedActions(stage_id)
        with open(self.paths['instruction']) as f:
            template = f.read()
            instruction_id = stage_id
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_INSTRUCTION_ID, str(instruction_id)).replace(ANNOTATION_ACTIONS, "\n".join([ x + ';' for x in p4code_actions[1] ]))
            f.close()
        lines = p4code.splitlines()
        tables = []
        for line in lines:
            if line.startswith('table'):
                tokens = line.split(' ')
                tables.append(tokens[1])
        return (p4code, tables, p4code_actions[0])

    def getGeneratedRegister(self, stage_id):
        p4code = None
        with open(self.paths['memory']) as f:
            template = f.read()
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id))
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
            table_code = ""
            action_code = ""
            register_code = ""
            hashing_code = ""
            table_names = []
            hash_idx = 0
            hash_algos = list(self.crc_16_params.keys())
            for i in range(offset, num_stages):
                instr_id = i
                tabledefs = self.getGeneratedTable(i)
                registerdefs = self.getGeneratedRegister(i)
                hash_algo = hash_algos[hash_idx]
                hash_idx = (hash_idx + 1) % len(hash_algos)
                hashdefs = self.getGeneratedHashing(i, hash_algo)
                table_code = table_code + "\n\n" + tabledefs[0]
                action_code = action_code + tabledefs[2]
                register_code = register_code + "\n\n" + registerdefs
                hashing_code = hashing_code + "\n\n" + hashdefs
                if self.truncate:
                    table_names = table_names + [('if(hdr.instr[%d].isValid()) { %s.apply(); hdr.instr[%d].setInvalid(); }' % (i, x, i)) for x in tabledefs[1]]
                else:
                    table_names = table_names + [('if(hdr.instr[%d].isValid()) { %s.apply(); }' % (i, x)) for x in tabledefs[1]]
                #table_names = table_names + [('if(hdr.instr[%d].isValid()) { meta.instr_count = meta.instr_count + 4; %s.apply(); hdr.instr[%d].flags = 1; }' % (i, x, i)) for x in tabledefs[1]]
            p4code = template.replace(ANNOTATION_ACTIONDEFS, action_code).replace(ANNOTATION_TABLES, table_code).replace(ANNOTATION_CTRLFLOW, "\n\t\t".join(table_names)).replace(ANNOTATION_MEMORY, register_code).replace(ANNOTATION_HASHDEFS, hashing_code)
            f.close()
        return p4code

generator = ActiveP4Generator(truncate=True)

with open('ingress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('ingress', 8))
    f.close()

with open('egress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('egress', 10))
    f.close()