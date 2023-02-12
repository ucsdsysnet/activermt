#!/usr/bin/python3

import os
import sys
import random
import numpy as np

from allocator import *

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

# experiment configuration parameters.

active_base_dir = '../apps'

paths_active_config = {
    'cache'     : '../apps/cache/active/cacheread',
    'cheetahlb' : '../apps/cheetahlb/active/cheetahlb-syn',
    'freqitem'  : '../apps/cache/active/freqitem'
}

appCfg = {}

apps = [ 'cache', 'freqitem', 'cheetahlb' ]

demands = {
    'cache'     : 1,    # elastic
    'cheetahlb' : 2,    # inelastic (512 entries)
    'freqitem'  : 16    # inelastic (error rate 0.1%)
}

analysisTypes = ['fit', 'duration']

# utility functions.

def logAllocation(expId, appname, numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("[%d] %s,%s,%d,%d,%f,%f,%f,%f", expId, appname, ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

def simAllocation(expId, appCfg, allocator, departures=False, online=True, debug=False, outputDir=None, allowFilling=False, durationTicks=60, arrivalRate=1, departureRate=1):
    rng = np.random.default_rng()
    DEPARTURE_RATE = departureRate
    ARRIVAL_RATE = arrivalRate
    apps = list(appCfg.keys())
    iter = 0
    costs = np.zeros(durationTicks, dtype=np.uint32)
    allocationTime = np.zeros(durationTicks)
    enumerationSizes = np.zeros(durationTicks, dtype=np.uint32)
    utilByIter = np.zeros(durationTicks, dtype=np.float64)
    occupancy = np.zeros(durationTicks, dtype=np.uint16)
    allocated = []
    allocated_appnames = []
    numDepartures = 0
    mutants = {}
    stageIds = []
    allocatedBlocks = []
    allocMatrices = []
    for t in range(0, durationTicks):
        if departures:
            nd = rng.poisson(lam=DEPARTURE_RATE)
            while nd > 0 and len(allocated) > 0:
                candidate = random.randint(0, len(allocated) - 1)
                depfid = allocated[candidate]
                allocator.deallocate(depfid)
                allocated.remove(depfid)
                numDepartures += 1
                nd -= 1
                if debug:
                    print("deallocated", depfid)
        numQueued = rng.poisson(lam=ARRIVAL_RATE)
        while numQueued > 0:
            appname = apps[random.randint(0, len(apps) - 1)]
            accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
            progLen = appCfg[appname]['applen']
            igLim = appCfg[appname]['iglim']
            minDemand = appCfg[appname]['mindemand']
            fid = iter + 1
            # allocate.
            activeFunc = ActiveFunction(fid, accessIdx, igLim, progLen, minDemand, enumerate=True, allow_filling=allowFilling)
            (allocation, cost, utilization, allocTime, overallAlloc, allocationMap) = allocator.computeAllocation(activeFunc, online=online)
            # get results.
            if allocation is not None and cost < allocator.WT_OVERFLOW:
                if appname not in mutants:
                    mutants[appname] = set()
                allocKey = ",".join([str(x) for x in allocation])
                mutants[appname].add(allocKey)
                stageIds.append(allocKey)
                (changes, _ ) = allocator.enqueueAllocation(overallAlloc, allocationMap)
                numChanges = 0
                for tid in changes:
                    numChanges += len(changes[tid])
                allocator.applyQueuedAllocation()
                blocks = allocator.getAllocationBlocks(fid)
                numBlocks = 0
                for sid in blocks:
                    numBlocks += len(blocks[sid])
                allocatedBlocks.append(numBlocks)
                allocMatrices.append(copy.deepcopy(allocator.allocationMatrix))
                costs[t] = numChanges
                allocationTime[t] = allocTime
                enumerationSizes[t] = activeFunc.getEnumerationSize()
                allocated.append(fid)
                allocated_appnames.append(appname)
                iter += 1
                if debug:
                    print("allocated", fid, "app", appname)
            else:
                stageIds.append("")
                allocatedBlocks.append(None)
                allocMatrices.append(None)
                if debug:
                    print("allocation failed for", appname, "seq", iter)
            numQueued -= 1
        utilByIter[t] = allocator.getUtilization()
        occupancy[t] = allocator.getOccupancy()
    stats = {
        'enumsizes'     : enumerationSizes,
        'alloctime'     : allocationTime,
        'costs'         : costs,
        'utilization'   : utilByIter,
        'occupancy'     : occupancy,
        'datalen'       : iter,
        'allocmatrix'   : allocator.allocationMatrix,
        'allocated'     : allocated,
        'appnames'      : allocated_appnames,
        'stages'        : stageIds,
        'numblocks'     : allocatedBlocks
    }
    if iter == 0:
        return (0, 0, {})
    # write stats.
    statkeys = ['enumsizes', 'alloctime', 'costs', 'utilization', 'appnames', 'stages', 'numblocks', 'occupancy']
    if outputDir is not None:
        statdir = os.path.join(os.getcwd(), outputDir, str(expId))
        if not os.path.exists(statdir):
            os.makedirs(statdir)
        for stat in statkeys:
            with open(os.path.join(statdir, "%s.csv" % stat), "w") as f:
                outdata = []
                if stats[stat] is not None:
                    outdata.append("\n".join([str(x) for x in stats[stat]]))
                f.write("\n".join(outdata))
                f.close()
        allocmatdir = os.path.join(statdir, "allocations")
        if not os.path.exists(allocmatdir):
            os.makedirs(allocmatdir)
        for i in range(0, len(allocMatrices)):
            with open(os.path.join(allocmatdir, "allocmatrix_%d.csv" % i), "w") as f:
                if allocMatrices[i] is not None:
                    f.write("\n".join([ ",".join([ str(x) for x in y ]) for y in allocMatrices[i] ]))
                f.close()
    utilization = allocator.getUtilization()
    return (utilization, numDepartures, mutants)

def generateSequence(appCfg, type='fixed', appname='cache', appSeqLen=100):
    apps = appCfg.keys()
    sequence = []
    i = 0
    while i < appSeqLen:
        if type == 'fixed':
            sequence.append(appname)
        else:
            sequence.append(apps[random.randint(0, len(apps) - 1)])
        i += 1
    return sequence

def runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=None, w='random', departures=False, debug=False, allowFilling=False, durationTicks=60, arrivalRate=1, departureRate=1):
    results = []
    param_workload = appname if w != 'random' else w
    param_fit = 'ff' if not optimize else ('wf' if minimize else 'bf')
    param_constr = 'lc' if allowFilling else 'mc'
    outputDirName = "timesimulation_stats_g%d_t%d_%s_%s_%s_a%d" % (Allocator.ALLOCATION_GRANULARITY, durationTicks, param_workload, param_fit, param_constr, arrivalRate)
    if os.path.exists(os.path.join(os.getcwd(), outputDirName)):
        raise Exception("Stats directory already exists! Remove/rename existing directory.")
    for k in range(0, numRepeats):
        allocator = Allocator(metric=metric, optimize=optimize, minimize=minimize)
        # result = (totalCost, utilization, utility, avgTime, numAllocated, numDepartures, stats)
        result = simAllocation(k, appCfg, allocator, departures=departures, debug=debug, outputDir=outputDirName, allowFilling=allowFilling, durationTicks=durationTicks, arrivalRate=arrivalRate, departureRate=departureRate)
        results.append(result)
    return results

# read application configurations.

for app in apps:
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
    print("Read app config for %s." % app)

logging.basicConfig(filename=os.path.join(BASE_PATH, 'logs/controller/simulator.log'), filemode='w', format='%(asctime)s - %(message)s', level=logging.INFO)

# Experiments.

custom = len(sys.argv) == 1
analysis_type = sys.argv[1] if len(sys.argv) > 1 else None

if custom:
    print("[Custom Experiment]")

    duration_ticks = 60
    numRepeats = 1
    type = 'random'
    appname = ''
    includeDepartures = True
    optimize = True
    minimize = True
    ignoreIglim = False
    allowFilling = ignoreIglim
    metric = Allocator.METRIC_COST
    granularity = Allocator.ALLOCATION_GRANULARITY
    if ignoreIglim:
        for app in appCfg:
            appCfg[app]['iglim'] = -1
    print("Running analysis with parameters: optimize=%s, minimize=%s, workload=%s, granularity=%d, ticks=%d, constrained=%s" % (str(optimize), str(minimize), (appname if type == 'fixed' else type), Allocator.ALLOCATION_GRANULARITY, duration_ticks, 'least' if allowFilling else 'most'))
    results = runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=appname, w=type, debug=False, departures=includeDepartures, allowFilling=allowFilling, durationTicks=duration_ticks)
elif analysis_type == 'duration':
    print("[Online Duration Based Simulation]")

    duration_ticks = 100
    numRepeats = 10
    type = 'random'

    includeDepartures = True
    optimize = True
    minimize = True
    metric = Allocator.METRIC_COST
    granularity = Allocator.ALLOCATION_GRANULARITY
    
    params_constraints = [False]
    params_arrival_factor = 2

    for c in params_constraints:
        ignoreIglim = c
        allowFilling = ignoreIglim
        if ignoreIglim:
            for app in appCfg:
                appCfg[app]['iglim'] = -1
        print("Running analysis with parameters: optimize=%s, minimize=%s, workload=random, granularity=%d, ticks=%d, constrained=%s, arrival_factor=%d" % (str(optimize), str(minimize), Allocator.ALLOCATION_GRANULARITY, duration_ticks, 'least' if allowFilling else 'most', params_arrival_factor))
        results = runAnalysis(appCfg, metric, optimize, minimize, numRepeats, w=type, debug=False, departures=includeDepartures, allowFilling=allowFilling, durationTicks=duration_ticks, arrivalRate=params_arrival_factor)

elif analysis_type == 'fit':
    workloads = appCfg.keys()
    workloads.append('random')

    param_fit = [(False, False), (True, True), (True, False)]

    numApps = 128
    numRepeats = 1

    for w in workloads:
        type = 'fixed' if w != 'random' else w
        appname = w
        for fit in param_fit:
            optimize = fit[0]
            minimize = fit[1]
            metric = Allocator.METRIC_COST
            useDepartures = False
            departureProb = 0
            print("Running analysis with parameters: optimize=%s, minimize=%s, workload=%s, granularity=%d, numapps=%d" % (str(optimize), str(minimize), w, Allocator.ALLOCATION_GRANULARITY, numApps))
            ts_start = time.time()
            results = runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=appname, w=type, debug=True, seqLen=numApps, departures=useDepartures, departureProb=departureProb)
            ts_end = time.time()
            ts_elapsed_sec = ts_end - ts_start
            print("Experiments complete after %f seconds." % ts_elapsed_sec)
else:
    print("valid analysis types:", analysisTypes)