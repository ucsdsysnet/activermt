#!/usr/bin/python

import random
import numpy as np

from allocator import *

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

def logAllocation(expId, appname, numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("[%d] %s,%s,%d,%d,%f,%f,%f,%f", expId, appname, ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

"""dbg_seq = {}
dbg_changes = {}
dbg_allocmatrix = {}
dbg_allocmap = {}"""
def simAllocation(expId, appCfg, allocator, sequence, departures=False, departureFID='random', departureProb=0.0, online=True, debug=False, outputDir=None, allowFilling=False):
    # global dbg_seq, dbg_changes, dbg_allocmatrix, dbg_allocmap
    # rng = np.random.default_rng()
    iter = 0
    sumCost = 0
    sumTime = 0
    costs = np.zeros(len(sequence), dtype=np.uint32)
    allocationTime = np.zeros(len(sequence))
    enumerationSizes = np.zeros(len(sequence), dtype=np.uint32)
    utilByIter = np.zeros(len(sequence))
    failed = set()
    allocated = []
    allocated_appnames = []
    if debug:
        print("Attempting allocation for sequence:", sequence)
    i = 0
    numDepartures = 0
    mutants = {}
    stageIds = []
    seqlen = len(sequence)
    allocatedBlocks = []
    allocMatrices = []
    while i < seqlen:
        appname = sequence[i]
        if debug:
            print("")
            print("Iteration", iter, "App", appname)
        # if departures and len(allocated) > 0 and random.random() < departureProb:
        #     if departureFID == 'random':
        #         candidate = random.randint(0, len(allocated) - 1)
        #         depfid = allocated[candidate]
        #     else:
        #         depfid = allocated[0]
        #     allocator.deallocate(depfid)
        #     allocated.remove(depfid)
        #     numDepartures += 1
        # if departures and len(allocated) > 0:
        #     nd = rng.poisson(lam=1)
        #     while nd > 0:
        #         candidate = random.randint(0, len(allocated) - 1)
        #         depfid = allocated[candidate]
        #         allocator.deallocate(depfid)
        #         allocated.remove(depfid)
        #         numDepartures += 1
        #         nd -= 1
        i += 1
        if appname in failed:
            continue
        accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
        progLen = appCfg[appname]['applen']
        igLim = appCfg[appname]['iglim']
        minDemand = appCfg[appname]['mindemand']
        fid = iter + 1
        tsBegin = time.time()
        activeFunc = ActiveFunction(fid, accessIdx, igLim, progLen, minDemand, enumerate=True, allow_filling=allowFilling)
        (allocation, cost, utilization, allocTime, overallAlloc, allocationMap) = allocator.computeAllocation(activeFunc, online=online)
        """if i in dbg_seq and not np.all(np.equal(allocation, dbg_seq[i])):
            print("Error!")
            print(dbg_seq[i])
            print(allocation)
            sys.exit(1)
        dbg_seq[i] = np.copy(allocation)"""
        if allocation is not None and cost < allocator.WT_OVERFLOW:
            if appname not in mutants:
                mutants[appname] = set()
            allocKey = ",".join([str(x) for x in allocation])
            mutants[appname].add(allocKey)
            stageIds.append(allocKey)
            (changes, remaps) = allocator.enqueueAllocation(overallAlloc, allocationMap)
            """if i in dbg_changes:
                prev_fids = set(dbg_changes[i].keys())
                new_fids = set(changes.keys())
                if prev_fids != new_fids:
                    print("SeqIdx", i)
                    print(dbg_changes[i])
                    print(changes)
                    print(dbg_allocmatrix[i])
                    print('===============================================')
                    print(allocator.allocationMatrix)
                    for s in range(0, 20):
                        assert dbg_allocmap[i][s] == allocationMap[s]
                assert set(dbg_changes[i].keys()) == set(changes.keys())
            dbg_changes[i] = copy.deepcopy(changes)
            dbg_allocmatrix[i] = np.copy(allocator.allocationMatrix)
            dbg_allocmap[i] = copy.deepcopy(allocationMap)"""
            numChanges = 0
            for tid in changes:
                numChanges += len(changes[tid])
                #numChanges += allocator.computeNumChanges()
            allocator.applyQueuedAllocation()
            blocks = allocator.getAllocationBlocks(fid)
            numBlocks = 0
            for sid in blocks:
                numBlocks += len(blocks[sid])
            allocatedBlocks.append(numBlocks)
            allocMatrices.append(copy.deepcopy(allocator.allocationMatrix))
            sumCost += numChanges
            sumTime += allocTime
            costs[iter] = numChanges
            allocationTime[iter] = allocTime
            enumerationSizes[iter] = activeFunc.getEnumerationSize()
            utilByIter[iter] = utilization
            allocated.append(fid)
            allocated_appnames.append(appname)
            iter += 1
        else:
            failed.add(appname)
            if debug:
                print("Allocation failed for", appname, "Seq", iter)
        tsEnd = time.time()
        elapsedSec = tsEnd - tsBegin
        # logAllocation(expId, appname, iter + 1, allocation, cost, elapsedSec, allocTime, activeFunc.getEnumerationTime(), utilization, online)
        if debug:
            print("Iter", i, "Cost", cost, "TIME_SECS", elapsedSec, "Enum Size", activeFunc.getEnumerationSize())
    stats = {
        'enumsizes'     : enumerationSizes,
        'alloctime'     : allocationTime,
        'costs'         : costs,
        'utilization'   : utilByIter,
        'datalen'       : iter,
        'allocmatrix'   : allocator.allocationMatrix,
        'allocated'     : allocated,
        'appnames'      : allocated_appnames,
        'stages'        : stageIds,
        'numblocks'     : allocatedBlocks
    }       
    if iter == 0:
        return (0, 0, 0, 0)
    # write stats.

    statkeys = ['enumsizes', 'alloctime', 'costs', 'utilization', 'appnames', 'stages', 'numblocks']
    if outputDir is not None:
        # statdirname = "stats_g%d_n%d" % (Allocator.ALLOCATION_GRANULARITY, seqlen)
        statdir = os.path.join(os.getcwd(), outputDir, str(expId))
        if not os.path.exists(statdir):
            os.makedirs(statdir)
        for stat in statkeys:
            with open(os.path.join(statdir, "%s.csv" % stat), "w") as f:
                outdata = []
                outdata.append("\n".join([str(x) for x in stats[stat]]))
                f.write("\n".join(outdata))
                f.close()
        allocmatdir = os.path.join(statdir, "allocations")
        if not os.path.exists(allocmatdir):
            os.makedirs(allocmatdir)
        for i in range(0, len(allocMatrices)):
            with open(os.path.join(allocmatdir, "allocmatrix_%d.csv" % i), "w") as f:
                f.write("\n".join([ ",".join([ str(x) for x in y ]) for y in allocMatrices[i] ]))
                f.close()
    avgTime = sumTime / iter
    utility = allocator.getOverallUtility()
    utilization = allocator.getUtilization()
    #print("Costs:", costs[0:iter])
    if debug:
        print("[OVERALL]")
        print("Apps allocated:", iter)
        print("Cost:", sumCost)
        print("Utility:", utility)
        print("Utilization:", utilization)
        print("Allocation:")
        print(allocator.allocationMatrix)
        """print("Allocation Times:", allocationTime)
        print("Costs:", costs)
        print("Enumeration sizes:", enumerationSizes)"""
    return (sumCost, utilization, utility, avgTime, iter, numDepartures, stats, mutants)

def simCompareAllocation(expId, appCfg, allocator, sequence):
    simAllocation(expId, appCfg, allocator, sequence, online=True)
    allocator.reset()
    simAllocation(expId, appCfg, allocator, sequence, online=False)

# analyses

active_base_dir = '../apps'

paths_active_config = {
    'cache'     : '../apps/cache/active/cacheread',
    'cheetahlb' : '../apps/cheetahlb/active/cheetahlb-syn',
    # 'freqitem'  : '../apps/scenario_distcache/active/freqitem'
    'freqitem'  : '../apps/cache/active/freqitem'
}

appCfg = {}

apps = [ 'cache', 'freqitem', 'cheetahlb' ]

demands = {
    'cache'     : 1,    # elastic
    'cheetahlb' : 2,    # inelastic (512 entries)
    'freqitem'  : 16    # inelastic (error rate 0.1%)
}

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

appSeqLen = 10
isOnline = True
compare = False

def testSequence(appname, appSeqLen, online=True, allocator=None):
    sequence = []
    if allocator is None:
        allocator = Allocator()
    for i in range(0, appSeqLen):
        sequence.append(appname)
    expId = 0
    simAllocation(expId, appCfg, allocator, sequence, online=online, debug=True)

def analysisExclusiveApp(expId, appSeqLen, isOnline):
    for appname in apps:
        sequence = []
        allocator = Allocator()
        for i in range(0, appSeqLen):
            sequence.append(appname)
        simAllocation(expId, appCfg, allocator, sequence, online=isOnline)

def analysisSampling(expId, appSeqLen, isOnline):
    sequence = []
    allocator = Allocator(debug=False)
    for i in range(0, appSeqLen):
        sequence.append(apps[random.randint(0, len(apps) - 1)])
    if compare:
        simCompareAllocation(expId, appCfg, allocator, sequence)
    else:    
        simAllocation(expId, appCfg, allocator, sequence, online=isOnline)

def printUsage():
    print("Usage: %s <exclusive|random|test> [num_repeats|appname]" % sys.argv[0])
    sys.exit(1)

if len(sys.argv) < 2:
    printUsage()

analysisType = sys.argv[1]

logging.basicConfig(filename=os.path.join(BASE_PATH, 'logs/controller/alloc_%s.log' % analysisType), filemode='w', format='%(asctime)s - %(message)s', level=logging.INFO)

# =================================================================

expId = 1
appname = 'cache'
type = 'fixed'
numRepeats = 1

metric = Allocator.METRIC_COST
optimize = True
minimize = True
departures = False
departureProb = 0.5
departureType = 'random'

def getParamString(optimize, minimize, metric, appname='cache', type='fixed', granularity=16):
    metrics = ['relocations', 'utility', 'utilization', 'sat']
    param_seq = appname if type == 'fixed' else 'random'
    param_fit = 'ff' if not optimize else ('bf' if minimize else 'wf')
    param_costmetric = metrics[metric]
    return "%s_%s_%s_%d" % (param_seq, param_fit, param_costmetric, granularity)

def writeResults(results, filename):
    with open(filename, 'w') as f:
        f.write("\n".join([",".join([ str(x) for x in y ]) for y in results]))
        f.close()

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

def runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=None, w='random', departures=False, departureFID='random', departureProb=0.0, expId=0, debug=False, fixedSequence=None, seqLen=256, allowFilling=False):
    results = []
    param_workload = appname if w != 'random' else w
    param_fit = 'ff' if not optimize else ('wf' if minimize else 'bf')
    param_constr = 'lc' if allowFilling else 'mc'
    outputDirName = "stats_g%d_n%d_%s_%s_%s" % (Allocator.ALLOCATION_GRANULARITY, seqLen, param_workload, param_fit, param_constr)
    if os.path.exists(os.path.join(os.getcwd(), outputDirName)):
        raise Exception("Stats directory already exists! Remove/rename existing directory.")
    for k in range(0, numRepeats):
        if fixedSequence is None:
            sequence = generateSequence(appCfg, appname=appname, appSeqLen=seqLen) if w != 'random' else generateSequence(appCfg, type='random', appSeqLen=seqLen)
        else:
            sequence = fixedSequence
        allocator = Allocator(metric=metric, optimize=optimize, minimize=minimize)
        # result = (totalCost, utilization, utility, avgTime, numAllocated, numDepartures, stats)
        result = simAllocation(k, appCfg, allocator, sequence, departures=departures, departureFID=departureFID, departureProb=departureProb, debug=False, outputDir=outputDirName, allowFilling=allowFilling)
        results.append(result[:6])
    # if debug:
    #     print(result[6]['allocmatrix'])
    return results

def print_allocation_matrix(allocation_matrix):
    buf = "\n".join([ " ".join([ str(j) for j in i ]) for i in allocation_matrix ])
    print("Allocation Matrix:")
    print(buf)

# Experiments.

custom = True

if custom:
    print("[Custom Experiment]")

    numApps = 4
    type = 'fixed'
    appname = 'cache'
    includeDepartures = False
    optimize = True
    minimize = True
    ignoreIglim = False
    allowFilling = ignoreIglim
    metric = Allocator.METRIC_COST
    granularity = Allocator.ALLOCATION_GRANULARITY
    if ignoreIglim:
        for app in appCfg:
            appCfg[app]['iglim'] = -1
    print("Running analysis with parameters: optimize=%s, minimize=%s, workload=%s, granularity=%d, numapps=%d, constrained=%s" % (str(optimize), str(minimize), (appname if type == 'fixed' else type), Allocator.ALLOCATION_GRANULARITY, numApps, 'least' if allowFilling else 'most'))
    results = runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=appname, w=type, debug=True, seqLen=numApps, departures=includeDepartures, departureProb=0.25, allowFilling=allowFilling)
    # writeResults(results, "allocation_%s.csv" % paramStr)
else:
    workloads = appCfg.keys()
    workloads.append('random')

    param_fit = [(False, False), (True, True), (True, False)]

    numApps = 128

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