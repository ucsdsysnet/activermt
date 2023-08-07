#!/usr/bin/python3

import sys

sys.path.insert(0, '../')

from allocator import *

active_base_dir = '../apps'

paths_active_config = {
    'cache'     : '../../apps/cache/active/cacheread',
    'cheetahlb' : '../../apps/cheetahlb/active/cheetahlb-syn',
    'freqitem'  : '../../apps/cache/active/freqitem'
}

demands = {
    'cache'     : 1,    # elastic
    'cheetahlb' : 2,    # inelastic (512 entries)
    'freqitem'  : 16    # inelastic (error rate 0.1%)
}

constr_filling = [False, True]

appCfg = {}

for app in paths_active_config:
    if app not in paths_active_config:
        continue
    if app not in appCfg:
        appCfg[app] = {}
    with open('%s.memidx.csv' % paths_active_config[app]) as f:
        data = f.read().splitlines()
        memidx = [ int(x) for x in data[0].split(",") ]
        iglim = int(data[1])
        appCfg[app]['idx'] = memidx
        appCfg[app]['iglim'] = iglim
        appCfg[app]['mindemand'] = [demands[app]] * len(memidx)
        f.close()
    with open('%s.ap4' % paths_active_config[app]) as f:
        data = f.read().strip().splitlines()
        appCfg[app]['applen'] = len(data)
        f.close()
    print("memidx: {}".format(appCfg[app]['idx']))
    print("Read app config for {}. Num accesses = {}".format(app, len(appCfg[app]['idx'])))

fid = 1
for allowFilling in constr_filling:
    mmap = np.zeros(20, dtype=np.uint32)
    for app in paths_active_config:
        accessIdx = np.transpose(np.array(appCfg[app]['idx'], dtype=np.uint32))
        progLen = appCfg[app]['applen']
        igLim = appCfg[app]['iglim'] if not allowFilling else -1
        minDemand = appCfg[app]['mindemand']
        program = ActiveFunction(fid, accessIdx, igLim, progLen, minDemand, enumerate=True, allow_filling=allowFilling)
        num_mutants = program.getEnumerationSize()
        enumeration = program.getEnumeration(transformed=True)
        print("Number of mutants for {} len={} (lc={}): {}/{}".format(app, progLen, allowFilling, num_mutants, len(enumeration)))
        # for mutant in enumeration:
        #     for idx in mutant:
        #         mmap[idx] += 1
        # print("MMAP for {} (allowFilling={}): {}".format(app, allowFilling, mmap))

"""
    Using a granularity of 256 objects (368 blocks).
"""