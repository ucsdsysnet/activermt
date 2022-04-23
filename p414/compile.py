#!/usr/bin/python

import os

IG_STEPS = 6
NUM_STEPS = 11 + IG_STEPS
NUM_BLOCKS = 16
BLOCK_SIZE = 4096
IG_COMPUTE = [2,3,4,5,6,7]

def generateMARActions():
    template = open('templates/template.mar.p4').read()
    actions = []
    for i in range(0, NUM_STEPS):
        for j in range(0, NUM_BLOCKS):
            actions.append(template
            .replace('#', str(i + 1))
            .replace('?', str(i))
            .replace('$', str(j * BLOCK_SIZE)))
    return "\n\n".join(actions)

def generateDependentActions():
    template = open('templates/template.actions.p4').read()
    actions = []
    hash_algos = [
        'en_13757',
        'dds_110',
        'dect',
        'dnp',
        'genibus',
        'maxim',
        'riello',
        'usb',
        'teledisk',
        'mcrf4xx',
        't10_dif'
    ]
    for i in range(0, NUM_STEPS):
        actions.append(template
            .replace('#', str(i + 1))
            .replace('?', str(i if i < IG_STEPS else i - IG_STEPS))
            .replace('$', hash_algos[i % len(hash_algos)]))
    return "\n\n".join(actions)

def generateMemoryConstructs():
    f_memory = open('templates/template.memory.p4')
    memoryTemplate = f_memory.read()
    memoryCode = []
    for i in range(0, NUM_STEPS):
        memoryCode.append(memoryTemplate
            .replace('#', str(i + 1))
            .replace('?', str(i))
        )
    return "\n\n".join(memoryCode)

def generateExecuteTables():
    f_execute = open('templates/template.execute.table.p4')
    f_execute_p = open('templates/template.execute.table.preload.p4')
    f_execute_ig = open('templates/template.execute.table.ig.p4')
    f_execute_ig_p = open('templates/template.execute.table.ig.preload.p4')
    executeTemplate = f_execute.read()
    executeTemplatePreload = f_execute_p.read()
    executeTemplateIg = f_execute_ig.read()
    executeTemplateIgPreload = f_execute_ig_p.read()
    executeCode = []
    for i in range(0, IG_STEPS):
        """marCalls = []
        for j in range(0, NUM_BLOCKS):
            marCalls.append("mar_load_%d_%d;" % (j * BLOCK_SIZE, i + 1))"""
        executeCode.append(executeTemplateIg
            #.replace('#mar_actions', "\n\t\t".join(marCalls))
            .replace('#', str(i + 1))
            .replace('?', str(i)))
        executeCode.append(executeTemplateIgPreload
            .replace('#', str(i + 1))
            .replace('?', str(i)))
    for i in range(IG_STEPS, NUM_STEPS):
        """marCalls = []
        for j in range(0, NUM_BLOCKS):
            marCalls.append("mar_load_%d_%d;" % (j * BLOCK_SIZE, i + 1))"""
        executeCode.append(executeTemplate
            #.replace('#mar_actions', "\n\t\t".join(marCalls))
            .replace('#', str(i + 1))
            .replace('?', str(i - IG_STEPS)))
        executeCode.append(executeTemplatePreload
            .replace('#', str(i + 1))
            .replace('?', str(i - IG_STEPS)))
    return "\n\n".join(executeCode)

def generateMarkTables():
    template = open('templates/template.mark.p4').read()
    markCode = []
    for i in range(0, NUM_STEPS):
        markCode.append(template
            .replace("#", str(i + 1))
            .replace("?", str(i if i < IG_STEPS else i - IG_STEPS)))
    return "\n\n".join(markCode)

# GENERATE: prototype.p4
with open('templates/template.prototype.p4') as f_active:
    generated = ""
    activeTemplate = f_active.read()
    generated = activeTemplate
    generated = generated.replace("#numsteps", str(NUM_STEPS))
    # generate ingress compute
    igtables = []
    igpreload = []
    for i in range(0, IG_STEPS):
        igtables.append("\t\t\t\t\tapply(proceed_%d);" % (i + 1))
        igtables.append("\t\t\t\t\tapply(execute_%d);" % (i + 1))
        igpreload.append("\t\t\t\t\tapply(cached_%d);" % (i + 1))
    generated = generated.replace('#igtables', "\n\t".join(igtables))
    generated = generated.replace('#precacheig', "\n\t".join(igpreload))
    # generate control
    tableCalls = []
    egpreload = []
    for i in range(IG_STEPS, NUM_STEPS):
        tableCalls.append("\tapply(proceed_%d);" % (i + 1))
        tableCalls.append("\tapply(execute_%d);" % (i + 1))
        egpreload.append("\tapply(cached_%d);" % (i + 1))
    generated = generated.replace("#tables", "\n\t".join(tableCalls))
    generated = generated.replace("#precacheeg", "\n\t".join(egpreload))
    with open('prototype.p4', 'w') as out:
        out.write(generated)
        out.close()
    f_active.close()

# GENERATE: egress/actions/stagewise.p4
with open('egress/actions/stagewise.p4', 'w') as out:
    out.write(generateDependentActions())
    out.close()

# GENERATE: memory.p4
with open('memory.p4', 'w') as out:
    out.write(generateMemoryConstructs())
    out.close()

# GENERATE: egress/execution.p4
with open('egress/execution.p4', 'w') as out:
    out.write(generateExecuteTables())
    out.close()

# GENERATE: egress/progress.p4
with open('egress/progress.p4', 'w') as out:
    out.write(generateMarkTables())
    out.close()