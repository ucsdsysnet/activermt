#!/usr/bin/python3

import os
import sys
import time
import logging

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/site-packages' % VERSION)

import numpy as np

# active function

class ActiveFunction:
    def __init__(self, fid, accessIdx, progLen, weight=1, enumerate=False):
        self.num_stages = 20
        self.fid = fid
        self.wt = weight
        self.progLen = progLen
        self.numAccesses = len(accessIdx)
        self.A = self.getDeltaMatrix(self.numAccesses)
        self.constrLB = np.copy(accessIdx)
        self.constrUB = self.constrLB + self.num_stages - self.progLen + 1
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
                    wtSum += WT_OVERFLOW
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
            for fid in self.activeFuncs:
                fids.append(fid)
                enumSizes.append(self.activeFuncs[fid].getEnumerationSize())
            radix = len(fids)
            current = np.zeros(radix, dtype=np.int32)
            while True:
                demand = np.zeros((radix, self.num_stages), dtype=np.uint8)
                for i in range(0, radix):
                    variant = self.activeFuncs[fids[i]].getVariant(current[i])
                    for j in range(0, len(variant)):
                        demand[i, variant[j]] = 1
                overlap = np.greater(np.sum(demand, axis=0), np.ones((1, self.num_stages)))
                numOverlaps = np.sum(overlap)
                if optimal is None:
                    minCost = numOverlaps
                    optimal = np.copy(current)
                if numOverlaps <    minCost:
                    minCost = numOverlaps
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
            else:
                self.allocation = set()
                self.allocationMap = {}
                # TODO add allocations
        tsAllocElapsed = time.time() - tsAllocStart
        utilization = len(self.allocation) / self.num_stages
        return (optimal,    minCost, utilization, tsAllocElapsed)

# main

BASE_PATH = os.environ['ACTIVEP4_SRC'] if 'ACTIVEP4_SRC' in os.environ else os.getcwd()

logging.basicConfig(filename=os.path.join(BASE_PATH, 'logs/controller/allocator.log'), format='%(asctime)s - %(message)s', level=logging.INFO)

def logAllocation(numApps, allocation, cost, elapsedTime, allocTime, enumTime, utilization, isOnline=True):
    logging.info("%s,%d,%d,%f,%f,%f,%f", ('ONLINE' if isOnline else 'OFFLINE'), numApps, cost, elapsedTime, allocTime, enumTime, utilization)

progLen = 12
accessIdx = np.transpose(np.array([3, 6, 9], dtype=np.uint32))

allocator = Allocator()

numApps = 10

for i in range(0, numApps):
    print("Iteration", i)
    tsBegin = time.time()
    activeFunc = ActiveFunction(1, accessIdx, progLen, enumerate=True)
    activeFunc.setFID(i + 1)
    (allocation, cost, utilization, allocTime) = allocator.allocate(activeFunc, online=True)
    tsEnd = time.time()
    elapsedSec = tsEnd - tsBegin
    logAllocation(i + 1, allocation, cost, elapsedSec, allocTime, activeFunc.getEnumerationTime(), utilization)
    print("Cost", cost, "TIME_SECS", elapsedSec)
    print("Allocation:")
    print(allocation, '/', allocator.getCurrentAllocation())
    # print("Overall:")
    # print(allocator.getCurrentAllocation())

#allocator.enumerate(callback=accumulate)
#print("Enum size", len(enumeration))
# print("\n".join([ ",".join([ str(x) for x in y ]) for y in enumeration ]))