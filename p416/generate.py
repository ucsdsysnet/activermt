#!/usr/bin/python3

import os
import sys

ANNOTATION_MAX_INSTR        = '<max-instructions>'
ANNOTATION_IG_STAGES        = '<ig-stages>'
ANNOTATION_EG_STAGES        = '<eg-stages>'
ANNOTATION_TOTAL_STAGES     = '<total-stages>'
ANNOTATION_SALT             = '<salt>'

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
ANNOTATION_LOADERS          = '<generated-loaders>'
ANNOTATION_LOADERDEFS       = '<generated-loader-defs>'

ANNOTATION_TP_DEFS_IG       = '<third-party-ig-defs>'
ANNOTATION_TP_DEFS_EG       = '<third-party-eg-defs>'
ANNOTATION_TP_CF_IG         = '<third-party-ig-cf>'
ANNOTATION_TP_CF_EG         = '<third-party-eg-cf>'
ANNOTATION_TP_MACROS        = '<generated-third-party-macros>'
ANNOTATION_TP_METADATA      = '<third-party-metadata>'

class ActiveP4Generator:

    NUM_ACTIVE_STAGES_IG    = 6
    NUM_ACTIVE_STAGES_EG    = 10
    MAX_INSTRUCTIONS        = 32
    SALT                    = 0x1234

    def __init__(self, truncate=False, third_party=None, ig_stages=NUM_ACTIVE_STAGES_IG, eg_stages=NUM_ACTIVE_STAGES_EG):
        self.truncate = truncate
        self.paths = {
            'main'          : 'templates/main.p4',
            'metadata'      : 'templates/metadata.p4',
            'actions'       : 'templates/actions.p4',
            'common-actions': 'templates/actions.common.p4',
            'data-actions'  : 'templates/actions.data.p4',
            'instruction'   : 'templates/instruction.p4',
            'malloc'        : 'templates/malloc.p4',
            'p1-instruction': 'templates/instruction.p1.p4',
            'memory'        : 'templates/memory.p4',
            'hashing'       : 'templates/hashing.p4',
            'ingress'       : 'templates/control.ingress.p4',
            'egress'        : 'templates/control.egress.p4',
            'loader'        : 'templates/loader.p4'
        }
        self.crc_16_params = {
            'crc_16'            : ('0x18005', 'true', '0x0000', '0x0000'),
            'crc_16_buypass'    : ('0x18005', 'false', '0x0000', '0x0000'),
            'crc_16_dds_110'    : ('0x18005', 'false', '0x800D', '0x0000'),
            'crc_16_dect'       : ('0x10589', 'false', '0x0001', '0x0001'),
            'crc_16_dnp'        : ('0x13D65', 'true', '0xFFFF', '0xFFFF'),
            'crc_16_en_13757'   : ('0x13D65', 'false', '0xFFFF', '0xFFFF'),
            'crc_16_genibus'    : ('0x11021', 'false', '0x0000', '0xFFFF'),
            'crc_16_maxim'      : ('0x18005', 'true', '0xFFFF', '0xFFFF'),
            'crc_16_mcrf4xx'    : ('0x11021', 'true', '0xFFFF', '0x0000'),
            'crc_16_riello'     : ('0x11021', 'true', '0x554D', '0x0000'),
            'crc_16_t10_dif'    : ('0x18BB7', 'false', '0x0000', '0x0000'),
            'crc_16_teledisk'   : ('0x1A097', 'false', '0x0000', '0x0000'),
            'crc_16_usb'        : ('0x18005', 'true', '0x0000', '0xFFFF')
        }
        self.registers = ('mar', 'mbr', 'mbr2')
        self.readonly = ('mar', 'mbr2')
        self.num_data = 4
        self.third_party = third_party
        self.NUM_ACTIVE_STAGES_IG = ig_stages
        self.NUM_ACTIVE_STAGES_EG = eg_stages

    def getThirdPartyProgram(self):

        ig_block_defs = ""
        ig_block_cf = ""
        eg_block_defs = ""
        eg_block_cf = ""
        macro_block = ""

        if self.third_party is None:
            return (ig_block_defs, ig_block_cf, eg_block_defs, eg_block_cf, macro_block)
        
        # assumes internet protocol headers: Ethernet, IPV4, TCP/UDP.
        ig_path = os.path.join('third-party', self.third_party, 'ingress.p4')
        eg_path = os.path.join('third-party', self.third_party, 'egress.p4')
        common_path = os.path.join('third-party', self.third_party, 'types.p4')

        with open(ig_path) as f:
            contents = f.read().strip()
            def_start = contents.index('<control-def>')
            def_end = contents.index('</control-def>')
            flow_start = contents.index('<control-flow>')
            flow_end = contents.index('</control-flow>')
            ig_block_defs = contents[def_start + len('<control-def>') : def_end]
            ig_block_cf = contents[flow_start + len('<control-flow>') : flow_end]
            f.close()

        with open(eg_path) as f:
            contents = f.read().strip()
            def_start = contents.index('<control-def>')
            def_end = contents.index('</control-def>')
            flow_start = contents.index('<control-flow>')
            flow_end = contents.index('</control-flow>')
            eg_block_defs = contents[def_start + len('<control-def>') : def_end]
            eg_block_cf = contents[flow_start + len('<control-flow>') : flow_end]
            f.close()

        with open(common_path) as f:
            contents = f.read().strip()
            macro_block = contents
            f.close()

        return (ig_block_defs, ig_block_cf, eg_block_defs, eg_block_cf, macro_block)

    def getGeneratedMetadata(self):
        p4code = None
        third_party_metadata = ""
        if self.third_party is not None:
            metadata_path = os.path.join('third-party', self.third_party, 'meta.p4')
            if os.path.exists(metadata_path):
                with open(metadata_path) as f:
                    contents = f.read()
                    meta_start = contents.index('<metadata>') + len('<metadata>')
                    meta_end = contents.index('</metadata>')
                    third_party_metadata = contents[meta_start:meta_end]
                    f.close()
        with open(self.paths['metadata']) as f:
            p4code = f.read()
            p4code = p4code.replace(ANNOTATION_TP_METADATA, third_party_metadata)
            f.close()
        return p4code

    def getGeneratedMain(self):
        p4code = None
        with open(self.paths['main']) as f:
            p4code = f.read()
            p4code = p4code.replace(ANNOTATION_MAX_INSTR, str(self.MAX_INSTRUCTIONS)).replace(ANNOTATION_IG_STAGES, str(self.NUM_ACTIVE_STAGES_IG)).replace(ANNOTATION_EG_STAGES, str(self.NUM_ACTIVE_STAGES_EG)).replace(ANNOTATION_TOTAL_STAGES, str(self.NUM_ACTIVE_STAGES_IG + self.NUM_ACTIVE_STAGES_EG)).replace(ANNOTATION_SALT, str(self.SALT))
            f.close()
        return p4code

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
            for i in range(0, self.num_data):
                data = "data_%d" % i
                for j in range(0, len(rw_templates)):
                    p4code.append(rw_templates[j].replace('<data>', data).replace('<data-id>', str(i)))
            """for i in range(0, len(self.registers)):
                reg = self.registers[i]
                for j in range(0, self.num_data):
                    data = "data_%d" % j
                    p4code.append(rw_templates[0].replace('<reg>', reg).replace('<data>', data).replace('<data-id>', str(j)))
                    if reg not in self.readonly:
                        p4code.append(rw_templates[1].replace('<reg>', reg).replace('<data>', data).replace('<data-id>', str(j)))
            if len(rw_templates) > 2:
                for j in range(0, self.num_data):
                    data = "data_%d" % j
                    p4code.append(rw_templates[2].replace('<data>', data).replace('<data-id>', str(j)))"""
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
    
    def getGeneratedLoader(self):
        p4code = None
        loaders = []
        with open(self.paths['loader']) as f:
            template = f.read().strip()
            defs = []
            for i in range(0, self.MAX_INSTRUCTIONS):
                defs.append(template.replace('#', str(i)))
                loaders.append('loader_%s.apply();' % i)
            p4code = "\n\n".join(defs)
            f.close()
        return (p4code, loaders)

    def getGeneratedControl(self, eg_ig):
        if eg_ig == 'ingress':
            num_stages = self.NUM_ACTIVE_STAGES_IG
            offset = 0
        else:
            num_stages = self.NUM_ACTIVE_STAGES_EG
            offset = self.NUM_ACTIVE_STAGES_IG
        p4code = None
        with open(self.paths[eg_ig]) as f:
            template = f.read()
            gen_common_actions = self.getCommonActions()
            gen_loaders, loaders = self.getGeneratedLoader()
            ig_block_defs, ig_block_cf, eg_block_defs, eg_block_cf, macro_block = self.getThirdPartyProgram()
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
            p4code = template.replace(ANNOTATION_ACTIONDEFS, action_code).replace(ANNOTATION_TABLES, table_code).replace(ANNOTATION_CTRLFLOW, "\n\t\t".join(table_names)).replace(ANNOTATION_MALLOC, "\n\t\t".join(malloc_tables)).replace(ANNOTATION_MEMORY, register_code).replace(ANNOTATION_HASHDEFS, hashing_code).replace(ANNOTATION_LOADERS, "\n\t\t".join(loaders)).replace(ANNOTATION_LOADERDEFS, gen_loaders)
            if eg_ig == 'ingress':
                p4code = p4code.replace(ANNOTATION_TP_MACROS, macro_block).replace(ANNOTATION_TP_DEFS_IG, ig_block_defs).replace(ANNOTATION_TP_CF_IG, ig_block_cf)
            else:
                p4code = p4code.replace(ANNOTATION_TP_MACROS, macro_block).replace(ANNOTATION_TP_DEFS_EG, eg_block_defs).replace(ANNOTATION_TP_CF_EG, eg_block_cf)
            f.close()
        return p4code

third_party_app = sys.argv[1] if len(sys.argv) > 1 else None
ig_stages = int(sys.argv[2]) if len(sys.argv) > 2 else ActiveP4Generator.NUM_ACTIVE_STAGES_IG
eg_stages = int(sys.argv[3]) if len(sys.argv) > 3 else ActiveP4Generator.NUM_ACTIVE_STAGES_EG

generator = ActiveP4Generator(truncate=True, third_party=third_party_app, ig_stages=ig_stages, eg_stages=eg_stages)

with open('active.p4', 'w') as f:
    f.write(generator.getGeneratedMain())
    f.close()

with open('metadata.p4', 'w') as f:
    f.write(generator.getGeneratedMetadata())
    f.close()

with open('ingress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('ingress'))
    f.close()

with open('egress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('egress'))
    f.close()