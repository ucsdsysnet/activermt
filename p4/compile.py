#!/usr/bin/python

import os

NUM_STEPS = 11
NUM_PAGES = 1
NUM_BLOCKS = 16
BLOCK_SIZE = 4096

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
            .replace('?', str(i))
            .replace('$', hash_algos[i]))
    return "\n\n".join(actions)

def generateMemoryConstructs():
    f_memory = open('templates/template.memory.p4')
    memoryTemplate = f_memory.read()
    memoryCode = []
    for i in range(0, NUM_STEPS * NUM_PAGES):
        memoryCode.append(memoryTemplate
            .replace('#', str(i + 1))
            .replace('?', str(i))
        )
    return "\n\n".join(memoryCode)

def generateExecuteTables():
    f_execute = open('templates/template.execute.table.p4')
    executeTemplate = f_execute.read()
    executeCode = []
    for i in range(0, NUM_STEPS):
        memoryCalls = []
        for j in range(0, NUM_PAGES):
            memoryCalls.append("memory_%d_read;" % (i * NUM_PAGES + j + 1))
            memoryCalls.append("memory_%d_write;" % (i * NUM_PAGES + j + 1))
        """marCalls = []
        for j in range(0, NUM_BLOCKS):
            marCalls.append("mar_load_%d_%d;" % (j * BLOCK_SIZE, i + 1))"""
        executeCode.append(executeTemplate
            .replace('#memory', "\n\t\t".join(memoryCalls))
            #.replace('#mar_actions', "\n\t\t".join(marCalls))
            .replace('#', str(i + 1))
            .replace('?', str(i)))
    return "\n\n".join(executeCode)

def generateMarkTables():
    template = open('templates/template.mark.p4').read()
    markCode = []
    for i in range(0, NUM_STEPS):
        markCode.append(template
            .replace("#", str(i + 1))
            .replace("?", str(i)))
    return "\n\n".join(markCode)

# GENERATE: prototype.p4
with open('templates/template.prototype.p4') as f_active:
    generated = ""
    activeTemplate = f_active.read()
    generated = activeTemplate
    generated = generated.replace("#numsteps", str(NUM_STEPS))
    # generate control
    tableCalls = []
    nestClosures = []
    for i in range(0, NUM_STEPS):
        tableCalls.append("%sapply(proceed_%d);" % ("\t" * i, i + 1))
        tableCalls.append("%sapply(execute_%d) { hit {" % ("\t" * i, i + 1))
        nestClosures.append("%s}}" % ("\t" * i))
    nestClosures.reverse()
    tableCalls = tableCalls + nestClosures
    generated = generated.replace("#tables", "\n\t".join(tableCalls))
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