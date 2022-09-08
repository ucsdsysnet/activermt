#!/usr/bin/python3

import os
import sys
import time
import random
import logging

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/site-packages' % VERSION)

import numpy as np

# active function

class ActiveFunction:
    def __init__(self, fid, accessIdx, igLim, progLen, weight=1, enumerate=False):
        self.num_stages = 20
        self.num_stage_ig = 10
        self.fid = fid
        self.wt = weight
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
        for i in range(0, self.num_stages):
            self.allocationMap[i] = set()
        self.activeFuncs = {}

    def getCurrentAllocation(self):
        return self.allocationMap

    def getCost(self, memIdx, activeFunc):
        wtSum = 0
        for idx in memIdx:
            if idx in self.allocation:
                if len(self.allocationMap[idx]) > self.max_occupancy:
                    wtSum += self.WT_OVERFLOW
                else:
                    for fid in self.allocationMap[idx]:
                        wtSum += self.activeFuncs[fid].wt
        return wtSum

    def allocate(self, activeFunc, online=True):
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
                for idx in optimal:
                    self.allocation.add(idx)
                    self.allocationMap[idx].add(activeFunc.getFID())
                utilization = len(self.allocation) / self.num_stages
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
                optimal = allocationMap
                utilization = len(allocation) / self.num_stages
        tsAllocElapsed = time.time() - tsAllocStart
        return (optimal, minCost, utilization, tsAllocElapsed)

# main

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

def logAllocation(expId, appname, numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("[%d] %s,%s,%d,%d,%f,%f,%f,%f", expId, appname, ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

def simAllocation(expId, appCfg, allocator, sequence, online=True):
    iter = 0
    for appname in sequence:
        print("Iteration", iter, "App", appname)
        accessIdx = np.transpose(np.array(appCfg[appname]['idx'], dtype=np.uint32))
        progLen = appCfg[appname]['applen']
        igLim = appCfg[appname]['iglim']
        fid = iter + 1
        tsBegin = time.time()
        activeFunc = ActiveFunction(1, accessIdx, igLim, progLen, enumerate=True)
        activeFunc.setFID(fid)
        (allocation, cost, utilization, allocTime) = allocator.allocate(activeFunc, online=online)
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
        'applen'    : 12
    },
    'cheetahlb' : {
        'idx'       : [1, 8, 10],
        'iglim'     : -1,
        'applen'    : 18
    },
    'cms'       : {
        'idx'       : [0, 1, 2, 3, 6, 8, 10, 18],
        'iglim'     : -1,
        'applen'    : 20
    }
}

apps = [ 'cache', 'cheetahlb', 'cms' ]

appSeqLen = 5
isOnline = False
compare = True

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
else:
    printUsage()