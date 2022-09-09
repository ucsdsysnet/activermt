#!/usr/bin/python

from allocator import *

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

def logAllocation(expId, appname, numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("[%d] %s,%s,%d,%d,%f,%f,%f,%f", expId, appname, ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

def simAllocation(expId, appCfg, allocator, sequence, online=True, debug=False):
    iter = 0
    for appname in sequence:
        print("")
        print("Iteration", iter, "App", appname)
        accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
        progLen = appCfg[appname]['applen']
        igLim = appCfg[appname]['iglim']
        minDemand = appCfg[appname]['mindemand']
        fid = iter + 1
        tsBegin = time.time()
        activeFunc = ActiveFunction(fid, accessIdx, igLim, progLen, minDemand, enumerate=True)
        (allocation, cost, utilization, allocTime, overallAlloc, allocationMap) = allocator.computeAllocation(activeFunc, online=online)
        if allocation is not None and cost < allocator.WT_OVERFLOW:
            (changes, remaps) = allocator.enqueueAllocation(overallAlloc, allocationMap)
            print("Changes", changes)
            allocator.applyQueuedAllocation()
        else:
            print("Allocation failed for", appname, "Seq", iter)
        tsEnd = time.time()
        elapsedSec = tsEnd - tsBegin
        logAllocation(expId, appname, iter + 1, allocation, cost, elapsedSec, allocTime, activeFunc.getEnumerationTime(), utilization, online)
        print("Cost", cost, "TIME_SECS", elapsedSec, "Enum Size", activeFunc.getEnumerationSize())
        iter += 1

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
    }
}

apps = [ 'cache', 'cheetahlb', 'cms' ]

appSeqLen = 5
isOnline = True
compare = False

def testSequence(appname, appSeqLen, online=True):
    sequence = []
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

# ANALYSIS: one app (of each type)
# ANALYSIS: probabilistic sampling (uniform)
# ANALYSIS: sorted by demand (decreasing)

if analysisType == "exclusive":
    numRepeats = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    for i in range(0, numRepeats):
        analysisExclusiveApp(i, appSeqLen, isOnline)
elif analysisType == "random":
    numRepeats = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    for i in range(0, numRepeats):
        analysisSampling(i, appSeqLen, isOnline)
elif analysisType == "test":
    allocator = Allocator()
    appname = sys.argv[2] if len(sys.argv) > 2 else 'cache'
    accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
    progLen = appCfg[appname]['applen']
    igLim = appCfg[appname]['iglim']
    activeFunc = ActiveFunction(1, accessIdx, igLim, progLen, enumerate=True)
    enumeration = activeFunc.getEnumeration()
    print("Enum size", len(enumeration))
    print("\n".join([ ",".join([ str(x) for x in y ]) for y in enumeration ]))
elif analysisType == "testseq":
    allocator = Allocator()
    appname = sys.argv[2] if len(sys.argv) > 2 else 'cache'
    testSequence(appname, appSeqLen)
else:
    printUsage()