#!/usr/bin/python3

import os
import sys
import time

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/site-packages' % VERSION)

import numpy as np

# active function

class ActiveFunction:
    def __init__(self, accessIdx, progLen, enumerate=False):
        self.num_stages = 20
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

    def getEnumeration(self):
        return self.enumeration

# allocator

class Allocator:
    def __init__(self):
        self.num_stages = 20
        self.allocation = set()

    def getNumOverlaps(self, memIdx):
        overlaps = 0
        for idx in memIdx:
            if idx in self.allocation:
                overlaps = overlaps + 1
        return overlaps

    def allocate(self, activeFunc, online=True):
        minOverlap = None
        optimal = None
        if online:
            enumeration = activeFunc.getEnumeration()
            for memIdx in enumeration:
                overlaps = self.getNumOverlaps(memIdx)
                if optimal is None:
                    minOverlap = overlaps
                    optimal = memIdx
                if overlaps < minOverlap:
                    minOverlap = overlaps
                    optimal = memIdx
        else:
            pass
        if optimal is not None:
            for idx in optimal:
                self.allocation.add(idx)
        return (optimal, minOverlap)

# main

progLen = 12
accessIdx = np.transpose(np.array([3, 6, 9], dtype=np.ulonglong))
activeFunc = ActiveFunction(accessIdx, progLen, enumerate=True)

print("Enumeration time", activeFunc.getEnumerationTime())

allocator = Allocator()

numApps = 10

for i in range(0, numApps):
    print("Iteration", i)
    tsBegin = time.time()
    (allocation, overlaps) = allocator.allocate(activeFunc)
    tsEnd = time.time()
    elapsedSec = tsEnd - tsBegin
    print("Overlaps", overlaps, "TIME_SECS", elapsedSec)
    print("Allocation:")
    print(allocation)

#allocator.enumerate(callback=accumulate)
#print("Enum size", len(enumeration))
# print("\n".join([ ",".join([ str(x) for x in y ]) for y in enumeration ]))