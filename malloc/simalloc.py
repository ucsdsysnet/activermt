#!/usr/bin/python

import random

from allocator import *

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

def logAllocation(expId, appname, numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("[%d] %s,%s,%d,%d,%f,%f,%f,%f", expId, appname, ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

"""dbg_seq = {}
dbg_changes = {}
dbg_allocmatrix = {}
dbg_allocmap = {}"""
def simAllocation(expId, appCfg, allocator, sequence, departures=False, departureFID='random', departureProb=0.0, online=True, debug=False):
    # global dbg_seq, dbg_changes, dbg_allocmatrix, dbg_allocmap
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
    seqlen = len(sequence)
    while i < seqlen:
        if debug:
            print("")
            print("Iteration", iter, "App", appname)
        if departures and len(allocated) > 0 and random.random() < departureProb:
            if departureFID == 'random':
                candidate = random.randint(0, len(allocated) - 1)
                depfid = allocated[candidate]
            else:
                depfid = allocated[0]
            allocator.deallocate(depfid)
            allocated.remove(depfid)
            numDepartures += 1
        appname = sequence[i]
        i += 1
        if appname in failed:
            continue
        accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
        progLen = appCfg[appname]['applen']
        igLim = appCfg[appname]['iglim']
        minDemand = appCfg[appname]['mindemand']
        fid = iter + 1
        tsBegin = time.time()
        activeFunc = ActiveFunction(fid, accessIdx, igLim, progLen, minDemand, enumerate=True)
        (allocation, cost, utilization, allocTime, overallAlloc, allocationMap) = allocator.computeAllocation(activeFunc, online=online)
        """if i in dbg_seq and not np.all(np.equal(allocation, dbg_seq[i])):
            print("Error!")
            print(dbg_seq[i])
            print(allocation)
            sys.exit(1)
        dbg_seq[i] = np.copy(allocation)"""
        if allocation is not None and cost < allocator.WT_OVERFLOW:
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
        #logAllocation(expId, appname, iter + 1, allocation, cost, elapsedSec, allocTime, activeFunc.getEnumerationTime(), utilization, online)
        if debug:
            print("Cost", cost, "TIME_SECS", elapsedSec, "Enum Size", activeFunc.getEnumerationSize())
    stats = {
        'enumsizes'     : enumerationSizes,
        'alloctime'     : allocationTime,
        'costs'         : costs,
        'utilization'   : utilByIter,
        'datalen'       : iter,
        'allocmatrix'   : allocator.allocationMatrix,
        'allocated'     : allocated,
        'appnames'      : allocated_appnames
    }
    if iter == 0:
        return (0, 0, 0, 0)
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
    return (sumCost, utilization, utility, avgTime, iter, numDepartures, stats)

def simCompareAllocation(expId, appCfg, allocator, sequence):
    simAllocation(expId, appCfg, allocator, sequence, online=True)
    allocator.reset()
    simAllocation(expId, appCfg, allocator, sequence, online=False)

# analyses

appCfg = {
    'cache'     : {
        'idx'       : [3, 6, 9],
        'iglim'     : 8,
        'applen'    : 12,
        'mindemand' : [1, 1, 1]
    },
    'cheetahlb' : {
        'idx'       : [1, 8, 10],
        'iglim'     : -1,
        'applen'    : 18,
        'mindemand' : [4, 4, 4]
    },
    'cms'       : {
        'idx'       : [3, 6, 8, 10, 18],
        'iglim'     : -1,
        'applen'    : 20,
        'mindemand' : [1, 1, 1, 1, 1]
    },
    'cache_hh'  : {
        'idx'       : [2,5,11,14,24,25,26],
        'iglim'     : 6,
        'applen'    : 28,
        'mindemand' : [1,1,1,1,1,1,1]
    }
}

apps = [ 'cache', 'cheetahlb', 'cms' ]

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
numRepeats = 100

metric = Allocator.METRIC_COST
optimize = True
minimize = True
departures = False
departureProb = 0.5
departureType = 'random'

def getParamString(optimize, minimize, metric, appname='cache', type='fixed'):
    metrics = ['relocations', 'utility', 'utilization', 'sat']
    param_seq = appname if type == 'fixed' else 'random'
    param_fit = 'ff' if not optimize else ('bf' if minimize else 'wf')
    param_costmetric = metrics[metric]
    return "%s_%s_%s" % (param_seq, param_fit, param_costmetric)

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

def runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=None, w='random', departures=False, departureFID='random', departureProb=0.0, expId=0, debug=False, fixedSequence=None):
    results = []
    for k in range(0, numRepeats):
        if fixedSequence is None:
            sequence = generateSequence(appCfg, appname=appname) if w != 'random' else generateSequence(appCfg, type='random')
        else:
            sequence = fixedSequence
        allocator = Allocator(metric=metric, optimize=optimize, minimize=minimize)
        # result = (totalCost, utilization, utility, avgTime, numAllocated, numDepartures, stats)
        result = simAllocation(expId, appCfg, allocator, sequence, departures=departures, departureFID=departureFID, departureProb=departureProb)
        results.append(result[:6])
    if debug:
        print(result[6]['allocmatrix'])
    return results

# METRICS: utilization, utility, cost, time
# ANALYSIS: one app (of each type)
# ANALYSIS: probabilistic sampling (uniform)
# ANALYSIS: only elastic app(s)
# ANALYSIS: only inelastic app
# ANALYSIS: fragmentation (arrival/departure)

custom = True

if custom:
    print("[Custom Experiment]")
    expId = 0

    appname = 'cache_hh'
    cfg = appCfg[appname]
    activeFunc = ActiveFunction(1, np.transpose(np.array(cfg['idx'], dtype=np.uint32)), cfg['iglim'], cfg['applen'], cfg['mindemand'], enumerate=True)
    print("Enumeration size: ", activeFunc.getEnumerationSize())
    enums = activeFunc.getEnumeration()
    print("\n".join([ ",".join([ str(x) for x in y ]) for y in enums ]))

    # sequence = generateSequence(appCfg, appname='cache_hh')
    # allocator = Allocator(metric=Allocator.METRIC_COST, optimize=True, minimize=True)
    # (sumCost, utilization, utility, avgTime, iter, numDepartures, stats) = simAllocation(expId, appCfg, allocator, sequence)
    # print("Utilization (cache_hh)", utilization)
    # print(stats['allocated'])
    # print(stats['appnames'])
    # print(stats['allocmatrix'])

    # sequence = generateSequence(appCfg, type='random')

    # results = runAnalysis(appCfg, Allocator.METRIC_SAT, False, False, numRepeats, w='random', debug=True, fixedSequence=sequence)
    # writeResults(results, "allocation_fixedwl_%s.csv" % getParamString(False, False, Allocator.METRIC_SAT, type='random'))

    # results = runAnalysis(appCfg, Allocator.METRIC_COST, True, True, numRepeats, w='random', debug=True, fixedSequence=sequence)
    # writeResults(results, "allocation_fixedwl_%s.csv" % getParamString(True, True, Allocator.METRIC_COST, type='random'))

    # activeFunc = ActiveFunction(1, np.transpose(np.array([4, 7, 9, 11], dtype=np.uint32)), 0, 14, [1, 1, 1, 1], enumerate=True)
    # enums = activeFunc.getEnumeration()
    # print("\n".join([ ",".join([ str(x) for x in y ]) for y in enums ]))
    
    # sequence = generateSequence(appCfg, appname='cache')
    # allocator = Allocator(metric=Allocator.METRIC_COST, optimize=True, minimize=True)
    # (sumCost, utilization, utility, avgTime, iter, numDepartures, stats) = simAllocation(expId, appCfg, allocator, sequence)
    # print("Utilization (cache)", utilization)
    # print(stats['allocated'])
    # print(stats['appnames'])
    # print(stats['allocmatrix'])

    # print("")

    # sequence = generateSequence(appCfg, type='random')
    # allocator = Allocator(metric=Allocator.METRIC_COST, optimize=True, minimize=True)
    # (sumCost, utilization, utility, avgTime, iter, numDepartures, stats) = simAllocation(expId, appCfg, allocator, sequence)
    # print("Utilization (random)", utilization)
    # print(stats['allocated'])
    # print(stats['appnames'])
    # print(stats['allocmatrix'])

    # sequence = generateSequence(appCfg, type='random')

    # allocator = Allocator(metric=Allocator.METRIC_COST, optimize=True, minimize=True)
    # (sumCost, utilization, utility, avgTime, iter, numDepartures, stats) = simAllocation(expId, appCfg, allocator, sequence)
    # print("Utilization (random, cost)", utilization)
    # print(stats['allocated'])
    # print(stats['appnames'])
    # print(stats['allocmatrix'])

    # print("")

    # allocator = Allocator(metric=Allocator.METRIC_SAT, optimize=False, minimize=False)
    # (sumCost, utilization, utility, avgTime, iter, numDepartures, stats) = simAllocation(expId, appCfg, allocator, sequence)
    # print("Utilization (random, strawman)", utilization)
    # print(stats['allocated'])
    # print(stats['appnames'])
    # print(stats['allocmatrix'])
else:
    param_fit = [(True, True), (True, False)]
    param_metric = [Allocator.METRIC_COST, Allocator.METRIC_UTILITY, Allocator.METRIC_UTILIZATION]

    workloads = appCfg.keys()
    workloads.append('random')

    # Strawman: get first-fit for each workload.
    for w in workloads:
        type = 'fixed' if w != 'random' else w
        appname = w
        optimize = False
        minimize = False
        metric = Allocator.METRIC_SAT
        paramStr = getParamString(optimize, minimize, metric, appname=appname, type=type)
        print("running analysis with params:", paramStr)
        results = runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=appname, w=type, debug=True)
        writeResults(results, "allocation_%s.csv" % paramStr)

    # Combinations: (first-fit, best-fit, worst-fit) x (relocations, utility, utilization).
    for w in workloads:
        type = 'fixed' if w != 'random' else w
        appname = w
        for p1 in param_metric:
            metric = p1
            for p2 in param_fit:
                optimize = p2[0]
                minimize = p2[1]
                paramStr = getParamString(optimize, minimize, metric, appname=appname, type=type)
                print("running analysis with params:", paramStr)
                results = runAnalysis(appCfg, metric, optimize, minimize, numRepeats, appname=appname, w=type, debug=True)
                writeResults(results, "allocation_%s.csv" % paramStr)

"""if analysisType == "exclusive":
    numRepeats = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    for i in range(0, numRepeats):
        analysisExclusiveApp(i, appSeqLen, isOnline)
elif analysisType == "random":
    numRepeats = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    for i in range(0, numRepeats):
        analysisSampling(i, appSeqLen, isOnline)
elif analysisType == "test":
    allocator = Allocator(metric=metric, optimize=optimize, minimize=minimize)
    appname = sys.argv[2] if len(sys.argv) > 2 else 'cache'
    accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
    progLen = appCfg[appname]['applen']
    igLim = appCfg[appname]['iglim']
    minDemand = appCfg[appname]['mindemand']
    activeFunc = ActiveFunction(1, accessIdx, igLim, progLen, minDemand, enumerate=True)
    enumeration = activeFunc.getEnumeration()
    print("Enum size", len(enumeration))
    print("\n".join([ ",".join([ str(x) for x in y ]) for y in enumeration ]))
elif analysisType == "testseq":
    allocator = Allocator(metric=metric, optimize=optimize, minimize=minimize)
    appname = sys.argv[2] if len(sys.argv) > 2 else 'cache'
    testSequence(appname, appSeqLen)
else:
    printUsage()"""