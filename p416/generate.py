#!/usr/bin/python3

ANNOTATION_STAGE_ID         = '<stage-id>'
ANNOTATION_INSTRUCTION_ID   = '<instruction-id>'
ANNOTATION_ACTIONS          = '<generated-actions>'
ANNOTATION_ACTIONDEFS       = '<generated-actions-defs>'
ANNOTATION_TABLES           = '<generated-tables>'
ANNOTATION_CTRLFLOW         = '<generated-ctrlflow>'
ANNOTATION_MEMORY           = '<register-defs>'

class ActiveP4Generator:

    def __init__(self):
        self.paths = {
            'actions'       : 'templates/actions.p4',
            'instruction'   : 'templates/instruction.p4',
            'memory'        : 'templates/memory.p4',
            'ingress'       : 'templates/control.ingress.p4',
            'egress'        : 'templates/control.egress.p4'
        }

    def getGeneratedActions(self, stage_id):
        p4code = None
        actions = []
        with open(self.paths['actions']) as f:
            template = f.read()
            instruction_id = stage_id - 1
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
            instruction_id = stage_id - 1
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id)).replace(ANNOTATION_INSTRUCTION_ID, str(instruction_id)).replace(ANNOTATION_ACTIONS, "\n".join([ x + ';' for x in p4code_actions[1] ]))
            f.close()
        lines = p4code.splitlines()
        table = None
        for line in lines:
            if line.startswith('table'):
                tokens = line.split(' ')
                table = tokens[1]
        return (p4code, table, p4code_actions[0])

    def getGeneratedRegister(self, stage_id):
        p4code = None
        with open(self.paths['memory']) as f:
            template = f.read()
            p4code = template.replace(ANNOTATION_STAGE_ID, str(stage_id))
            f.close()
        return p4code

    def getGeneratedControl(self, eg_ig, stage_offset, num_stages):
        p4code = None
        with open(self.paths[eg_ig]) as f:
            template = f.read()
            table_code = ""
            action_code = ""
            register_code = ""
            table_names = []
            for i in range(stage_offset, stage_offset + num_stages):
                tabledefs = self.getGeneratedTable(i)
                registerdefs = self.getGeneratedRegister(i)
                table_code = table_code + "\n\n" + tabledefs[0]
                action_code = action_code + tabledefs[2]
                register_code = register_code + "\n\n" + registerdefs
                table_names.append(tabledefs[1])
            p4code = template.replace(ANNOTATION_ACTIONDEFS, action_code).replace(ANNOTATION_TABLES, table_code).replace(ANNOTATION_CTRLFLOW, "\n\t\t".join([ ('%s.apply();' % x) for x in table_names ])).replace(ANNOTATION_MEMORY, register_code)
            f.close()
        return p4code

generator = ActiveP4Generator()

with open('ingress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('ingress', 1, 10))
    f.close()

with open('egress/control.p4', 'w') as f:
    f.write(generator.getGeneratedControl('egress', 1, 10))
    f.close()