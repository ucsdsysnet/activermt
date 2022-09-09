#!/usr/bin/python3

import os
import sys
import time
import copy
import math
import random
import logging

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/site-packages' % VERSION)

import numpy as np

# active function

class ActiveFunction:
    def __init__(self, fid, accessIdx, igLim, progLen, weight=1, minDemand=1, enumerate=False):
        self.num_stages = 20
        self.num_stage_ig = 10
        self.fid = fid
        self.wt = weight
        self.minDemand = minDemand
        self.igLim = igLim
        self.progLen = progLen
        self.numAccesses = len(accessIdx)
        self.A = self.getDeltaMatrix(self.numAccesses)
        self.constrLB = np.copy(accessIdx)
        self.constrUB = self.constrLB + self.num_stages - self.progLen + 1
        if self.igLim >= 0:
            for i in range(0, self.numAccesses):
                if self.constrLB[i] < self.igLim:
                    self.constrUB[i] = self.constrLB[i] + self.num_stage_ig - self.igLim - 1
        self.constrDelta = np.matmul(self.A, self.constrLB)
        self.enumeration = []
        self.enumTime = None
        if enumerate:
            self.enumerate()

    def setFID(self, fid):
        self.fid = fid

    def getFID(self):
        return self.fid

    def getEnumerationSize(self):
        return len(self.enumeration)

    def getEnumerationTime(self):
        return self.enumTime

    def getDeltaMatrix(self, numAccesses):
        A = np.zeros((numAccesses, numAccesses), dtype=np.ulonglong)
        A[0, 0] = 1
        for i in range(1, numAccesses):
            A[i, i - 1] = -1
            A[i, i] = 1
        return A

    def enumerate(self, initial=None, callback=None):
        radix = len(self.constrLB)
        current = np.copy(self.constrLB) if initial is None else initial
        tsEnumStart = time.time()
        while True:
            if callback is not None:
                callback(np.copy(current))
            else:
                self.enumeration.append(np.copy(current))
            pos = radix - 1
            while pos >= 0 and (current[pos] + 1) > self.constrUB[pos]:
                pos = pos - 1
            if pos < 0:
                break
            current[pos] = current[pos] + 1
            for i in range(pos + 1, radix):
                current[i] = current[i - 1] + self.constrDelta[i]
        tsEnumEnd = time.time()
        self.enumTime = tsEnumEnd - tsEnumStart

    def getVariant(self, idx):
        if idx < len(self.enumeration):
            return self.enumeration[idx]
        return None

    def getEnumeration(self):
        return self.enumeration

# allocator

class Allocator:
    def __init__(self):
        self.num_stages = 20
        self.max_occupancy = 8
        self.WT_OVERFLOW = 1000
        self.reset()

    def reset(self):
        self.allocation = set()
        self.allocationMap = {}
        self.revAllocationMap = {}
        for i in range(0, self.num_stages):
            self.allocationMap[i] = set()
        self.activeFuncs = {}
        self.allocationMatrix = np.zeros((self.max_occupancy, self.num_stages), dtype=np.uint32)
        self.queue = {
            'fid'               : None,
            'allocation'        : set(),
            'allocationMap'     : {},
            'revAllocationMap'  : {},
            'allocationMatrix'  : None
        }

    def getCurrentAllocation(self):
        return self.allocationMap

    # cost = sum of weighted overlaps.
    def getCost(self, memIdx, activeFunc):
        wtSum = 0
        for idx in memIdx:
            minDemand = 0
            for fid in self.allocationMap[idx]:
                wtSum += self.activeFuncs[fid].wt
                minDemand += self.activeFuncs[fid].minDemand
            minDemand += activeFunc.minDemand
            if len(self.allocationMap[idx]) != 0:
                wtSum += activeFunc.wt
            if minDemand > self.max_occupancy:
                wtSum += self.WT_OVERFLOW
            pass
            """if idx in self.allocation:
                if len(self.allocationMap[idx]) > self.max_occupancy:
                    wtSum += self.WT_OVERFLOW
                else:
                    # how costly is it to use a particular stage?
                    for fid in self.allocationMap[idx]:
                        wtSum += self.activeFuncs[fid].wt
                    wtSum += activeFunc.wt"""
        return wtSum

    def compareAllocations(self, A, B):
        result = np.equal(A, B)
        return np.all(result)

    def computeChanges(self, allocationMap):
        revAllocationMap = {}
        currentSharing = np.zeros(self.num_stages, dtype=np.uint32)
        sharing = np.zeros(self.num_stages, dtype=np.uint32)
        for i in range(0, self.num_stages):
            sharing[i] = len(allocationMap[i])
            currentSharing[i] = len(self.allocationMap[i])
            for fid in allocationMap[i]:
                if fid not in revAllocationMap:
                    revAllocationMap[fid] = []
                revAllocationMap[fid].append(i)
        changes = {}
        print(sharing)
        print(currentSharing)
        print(revAllocationMap)
        print(self.revAllocationMap)
        for fid in revAllocationMap:
            if fid not in self.revAllocationMap:
                continue
            A = self.revAllocationMap[fid]
            B = revAllocationMap[fid]
            for i in range(0, len(A)):
                resize = (currentSharing[A[i]] != sharing[B[i]])
                if A[i] != B[i] or resize:
                    if fid not in changes:
                        changes[fid] = []
                    changes[fid].append((A[i], B[i], resize))
        return changes

    def computeAllocation(self, activeFunc, online=True):
        self.queue['fid'] = activeFunc.getFID()
        self.activeFuncs[activeFunc.getFID()] = activeFunc
        minCost = None
        optimal = None
        tsAllocStart = time.time()
        if online:
            enumeration = activeFunc.getEnumeration()
            for memIdx in enumeration:
                cost = self.getCost(memIdx, activeFunc)
                if optimal is None:
                    minCost = cost
                    optimal = memIdx
                if cost < minCost:
                    minCost = cost
                    optimal = memIdx
        else:
            enumSizes = []
            fids = []
            weights = {}
            for fid in self.activeFuncs:
                fids.append(fid)
                enumSizes.append(self.activeFuncs[fid].getEnumerationSize())
                weights[fid] = self.activeFuncs[fid].wt
            radix = len(fids)
            current = np.zeros(radix, dtype=np.int32)
            while True:
                allocationMap = {}
                for i in range(0, radix):
                    variant = self.activeFuncs[fids[i]].getVariant(current[i])
                    for j in range(0, len(variant)):
                        if variant[j] not in allocationMap:
                            allocationMap[variant[j]] = set()
                        allocationMap[variant[j]].add(fids[i])
                cost = 0
                for idx in allocationMap:
                    if len(allocationMap[idx]) > 1:
                        for fid in allocationMap[idx]:
                            cost += weights[fid]
                if optimal is None:
                    minCost = cost
                    optimal = np.copy(current)
                if cost < minCost:
                    minCost = cost
                    optimal = np.copy(current)
                pos = radix - 1
                while pos >= 0 and current[pos] + 1 >= enumSizes[pos]:
                    pos = pos - 1
                if pos < 0:
                    break
                current[pos] = current[pos] + 1
                for i in range(pos + 1, radix):
                    current[i] = 0
        if optimal is not None:
            if online:
                allocation = self.allocation.copy()
                allocationMap = copy.deepcopy(self.allocationMap)
                for idx in optimal:
                    allocation.add(idx)
                    allocationMap[idx].add(activeFunc.getFID())
                utilization = len(allocation) / self.num_stages
            else:
                allocation = set()
                allocationMap = {}
                for i in range(0, self.num_stages):
                    allocationMap[i] = set()
                for i in range(0, radix):
                    variant = self.activeFuncs[fids[i]].getVariant(optimal[i])
                    for idx in variant:
                        allocation.add(idx)
                        allocationMap[idx].add(fids[i])
                optimal = variant
                utilization = len(allocation) / self.num_stages
        tsAllocElapsed = time.time() - tsAllocStart
        if minCost > self.WT_OVERFLOW:
            # allocation failed.
            optimal = None
            self.activeFuncs.pop(activeFunc.getFID())
        return (optimal, minCost, utilization, tsAllocElapsed, allocation, allocationMap)
    
    def computeAllocationMatrix(self, allocationMap):
        allocationMatrix = np.zeros((self.max_occupancy, self.num_stages), dtype=np.uint32)
        for i in range(0, self.num_stages):
            if len(allocationMap[i]) == 0:
                continue
            apps = [ (fid, self.activeFuncs[fid].wt, self.activeFuncs[fid].minDemand) for fid in allocationMap[i] ]
            sharing = len(apps)
            numBlocks = {}
            wtSum = 0
            maxWt = 0
            dominantFID = None
            apps.sort(key=lambda x: x[0])
            # assuming ordered in increasing FID value.
            for app in apps:
                wtSum += app[1]
                if app[1] >= maxWt:
                    maxWt = app[1]
                    dominantFID = app[0]
            sumBlocks = 0
            remaining = self.max_occupancy
            apps.sort(key=lambda x: x[1])
            for app in apps:
                fid = app[0]
                wt = app[1]
                minDemand = app[2]
                if remaining <= 0:
                    print("Error: out of memory!")
                    return None
                # in increasing order of weights (to avoid starvation of apps).
                numBlocks[fid] = min(max(math.floor(wt * self.max_occupancy / wtSum), minDemand), remaining)
                if minDemand > 1:
                    numBlocks[fid] = minDemand
                sumBlocks += numBlocks[fid]
                remaining -= numBlocks[fid]
            if remaining < 0:
                print("Error: out of memory!")
                return None
            # assign remaining to one with max weight or newest app (maximize utilization).
            numBlocks[dominantFID] += remaining
            # retain previously allocated blocks for inelastic apps by pinning them in order of arrival.
            apps.sort(key=lambda x: x[0] if x[2] > 1 else self.WT_OVERFLOW)
            # update the allocation matrix.
            offset = 0
            for app in apps:
                fid = app[0]
                for j in range(0, numBlocks[fid]):
                    allocationMatrix[offset + j, i] = fid
                offset += numBlocks[fid]
        return allocationMatrix

    def updateAllocation(self, allocation, allocationMap):
        allocationMatrix = self.computeAllocationMatrix(allocationMap)
        changes = self.computeChanges(allocationMap)
        print("Changes", changes)
        remaps = {}
        for fid in changes:
            remaps[fid] = []
            for remap in changes[fid]:
                if remap[2]:
                    # resized 
                    prevAlloc = []
                    newAlloc = []
                    for i in range(0, self.max_occupancy):
                        if self.allocationMatrix[i, remap[0]] == fid:
                            prevAlloc.append(i)
                        if allocationMatrix[i, remap[1]] == fid:
                            newAlloc.append(i)
                    remaps[fid].append((remap[0], prevAlloc, remap[1], newAlloc))
                    print("FID", fid, "Stage (from)", remap[0], "blocks", prevAlloc, "Stage (to)", remap[1], "blocks", newAlloc)
                else:
                    # TODO (optional) relocated (applicable for globally optimal allocations).
                    pass

        # queue new allocation.
        self.queue['allocation'] = copy.deepcopy(allocation)
        self.queue['allocationMap'] = copy.deepcopy(allocationMap)
        self.queue['revAllocationMap'] = {}
        for i in range(0, self.num_stages):
            for fid in self.queue['allocationMap'][i]:
                if fid not in self.queue['revAllocationMap']:
                    self.queue['revAllocationMap'][fid] = []
                self.queue['revAllocationMap'][fid].append(i)
        self.queue['allocationMatrix'] = copy.deepcopy(allocationMatrix)
        
        # TODO move memory objects between these locations.
        # TODO apply changes.

        return (changes, remaps)

    def applyQueuedAllocation(self):
        self.allocation = copy.deepcopy(self.queue['allocation'])
        self.allocationMap = copy.deepcopy(self.queue['allocationMap'])
        self.revAllocationMap = copy.deepcopy(self.queue['revAllocationMap'])
        self.allocationMatrix = copy.deepcopy(self.queue['allocationMatrix'])

# main

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

def logAllocation(expId, appname, numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("[%d] %s,%s,%d,%d,%f,%f,%f,%f", expId, appname, ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

def simAllocation(expId, appCfg, allocator, sequence, online=True, debug=False):
    iter = 0
    for appname in sequence:
        print("Iteration", iter, "App", appname)
        accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
        progLen = appCfg[appname]['applen']
        igLim = appCfg[appname]['iglim']
        minDemand = appCfg[appname]['mindemand']
        fid = iter + 1
        tsBegin = time.time()
        activeFunc = ActiveFunction(1, accessIdx, igLim, progLen, minDemand=minDemand, enumerate=True)
        activeFunc.setFID(fid)
        (allocation, cost, utilization, allocTime, overallAlloc, allocationMap) = allocator.computeAllocation(activeFunc, online=online)
        if allocation is not None:
            (changes, remaps) = allocator.updateAllocation(overallAlloc, allocationMap)
            allocator.applyQueuedAllocation()
        else:
            print("Allocation failed for", appname, "Seq", iter)
        tsEnd = time.time()
        elapsedSec = tsEnd - tsBegin
        logAllocation(expId, appname, iter + 1, allocation, cost, elapsedSec, allocTime, activeFunc.getEnumerationTime(), utilization, online)
        print("Cost", cost, "TIME_SECS", elapsedSec, "Enum Size", activeFunc.getEnumerationSize())
        print("Allocation:")
        print(allocation, '/', allocator.getCurrentAllocation())
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
        'mindemand' : 1
    },
    'cheetahlb' : {
        'idx'       : [1, 8, 10],
        'iglim'     : -1,
        'applen'    : 18,
        'mindemand' : 4
    },
    'cms'       : {
        'idx'       : [0, 1, 2, 3, 6, 8, 10, 18],
        'iglim'     : -1,
        'applen'    : 20,
        'mindemand' : 1
    }
}

apps = [ 'cache', 'cheetahlb', 'cms' ]

appSeqLen = 5
isOnline = False
compare = True

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
    allocator = Allocator()
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