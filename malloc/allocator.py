#!/usr/bin/python3

import os
import sys
import time
import copy
import math
import json
import random
import logging

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/site-packages' % VERSION)

import numpy as np

# active function

class ActiveFunction:
    def __init__(self, fid, accessIdx, igLim, progLen, minDemand, weight=1, enumerate=False):
        assert len(accessIdx) == len(minDemand)
        # assert progLen <= 20
        self.debug = False
        self.num_stages = 20
        self.num_stage_ig = 10
        self.num_stage_eg = self.num_stages - self.num_stage_ig
        self.fid = fid
        self.wt = weight
        self.igLim = igLim
        self.progLen = progLen
        self.minDemand = minDemand
        # ensuring re-circulation cost does not increase.
        self.maxProgLen = self.progLen if self.progLen <= self.num_stages else self.num_stage_ig + int(math.ceil((self.progLen - self.num_stage_ig) * 1.0 / self.num_stage_eg) * self.num_stage_eg)
        self.numAccesses = len(accessIdx)
        self.A = self.getDeltaMatrix(self.numAccesses)
        self.constrLB = np.copy(accessIdx).astype('uint32')
        self.constrUB = self.constrLB + self.maxProgLen - self.progLen - 1
        # self.constrUB = self.constrLB + self.num_stages - self.progLen - 1
        # self.constrUB = self.constrLB + self.num_stages - self.progLen + 1
        if self.igLim >= 0:
            for i in range(0, self.numAccesses):
                if self.constrLB[i] < self.igLim:
                    self.constrUB[i] = self.constrLB[i] + self.num_stage_ig - self.igLim - 1
        self.constrDelta = np.matmul(self.A, self.constrLB)
        if self.debug:
            print("[DEBUG] Maximum program length:", self.maxProgLen)
            print("[DEBUG] Constraint (UB):")
            print(self.constrUB)
        self.allocation = None
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
        # prune enumeration.
        pruned = []
        for enum in self.enumeration:
            x = [ (y if y < self.num_stage_ig else y % self.num_stage_eg + self.num_stage_ig) for y in enum ]
            if len(np.unique(x)) == len(x):
                pruned.append(enum)
        self.enumeration = pruned
        tsEnumEnd = time.time()
        self.enumTime = tsEnumEnd - tsEnumStart

    def getVariant(self, idx):
        if idx < len(self.enumeration):
            return self.enumeration[idx]
        return None

    def getEnumeration(self, transformed=False):
        if transformed:
            transformed = []
            for enum in self.enumeration:
                x = [ (y if y < self.num_stage_ig else y % self.num_stage_eg + self.num_stage_ig) for y in enum ]
                if len(np.unique(x)) == len(x):
                    transformed.append(x)
            return transformed
        return self.enumeration

# allocator

class Allocator:

    METRIC_COST = 0
    METRIC_UTILITY = 1
    METRIC_UTILIZATION = 2
    METRIC_SAT = 3
    ALLOCATION_GRANULARITY = 256
    ALLOCATION_TYPE_DEFAULT = 0
    ALLOCATION_TYPE_MAXMINFAIR = 1

    def __init__(self, metric=0, optimize=True, minimize=True, debug=False):
        self.num_stages = 20
        self.max_occupancy = self.ALLOCATION_GRANULARITY
        self.WT_OVERFLOW = 1000
        self.metric = metric
        self.optimize = optimize
        self.minimize = minimize
        self.allocation_type = self.ALLOCATION_TYPE_MAXMINFAIR
        self.DEBUG = debug
        self.reset()

    def reset(self):
        self.allocation = set()
        self.allocationMap = {}
        self.revAllocationMap = {}
        for i in range(0, self.num_stages):
            self.allocationMap[i] = set()
        self.activeFuncs = {}
        self.allocationMatrix = np.zeros((self.max_occupancy, self.num_stages), dtype=np.uint32)
        self.resetQueue()

    def resetQueue(self):
        self.queue = {
            'fid'               : None,
            'allocation'        : set(),
            'allocationMap'     : {},
            'revAllocationMap'  : {},
            'allocationMatrix'  : None
        }

    def save(self):
        """snapshot = {
            'allocation'        : self.allocation,
            'allocationMap'     : self.allocationMap,
            'revAllocationMap'  : self.revAllocationMap,
            'activeFuncs'       : self.activeFuncs,
            'allocationMatrix'  : self.allocationMatrix
        }
        data = json.dumps(snapshot, indent=4)
        with open('allocator.snapshot.json', 'w') as f:
            f.write(data)
            f.close()"""
        pass

    def getMinDemand(self, fid, idx):
        return self.activeFuncs[fid].minDemand[self.activeFuncs[fid].allocation[idx]]

    def getOverallUtility(self):
        utility = 0.0
        utilityByFunc = {}
        for i in range(0, self.num_stages):
            for j in range(0, self.max_occupancy):
                fid = self.allocationMatrix[j, i]
                if fid == 0:
                    continue
                if fid not in utilityByFunc:
                    utilityByFunc[fid] = {}
                if i not in utilityByFunc[fid]:
                    utilityByFunc[fid][i] = 0.0
                utilityByFunc[fid][i] += 1
        for fid in utilityByFunc:
            utilAcrossStages = 0.0
            for stageId in utilityByFunc[fid]:
                utilAcrossStages += (utilityByFunc[fid][stageId] / self.max_occupancy) if self.getMinDemand(fid, stageId) == 1 else 1
            utilAcrossStages /= len(utilityByFunc[fid])
            utility += utilAcrossStages
        return (utility * 1.0 / len(utilityByFunc))

    # utilization = fraction of total memory blocks used.
    def getUtilization(self):
        utilization = 0.0
        numBlocksTotal = self.max_occupancy * self.num_stages
        for i in range(0, self.max_occupancy):
            for j in range(0, self.num_stages):
                utilization += 1 if self.allocationMatrix[i, j] > 0 else 0
        return (utilization * 1.0 / numBlocksTotal)

    # utilization increase = number of additional memory blocks utilized.
    def getUtilizationIncrease(self, memIdx, activeFunc):
        utilization = 0
        numBlocksTotal = self.max_occupancy * self.num_stages
        numAccesses = len(memIdx)
        for i in range(0, numAccesses):
            idx = memIdx[i]
            occupied = 0
            elastic = False
            for fid in self.allocationMap[idx]:
                occupied += self.getMinDemand(fid, idx)
                if self.getMinDemand(fid, idx) == 1:
                    elastic = True
            remaining = self.max_occupancy - occupied - activeFunc.minDemand[i]
            if remaining < 0:
                return -1
            utilization += 0 if elastic else (activeFunc.minDemand[i] if activeFunc.minDemand[i] > 1 else remaining)
        return utilization

    # cost = number of data moving required to accomodate new app.
    # alternative: decrease in utility of other apps - difficult to estimate fairly since utility functions may vary across apps.
    def getCostMoving(self, memIdx, activeFunc):
        cost = 0
        numAccesses = len(memIdx)
        for i in range(0, numAccesses):
            idx = memIdx[i]
            occupied = 0
            for fid in self.allocationMap[idx]:
                if self.getMinDemand(fid, idx) == 1:
                    cost += 1
                occupied += self.getMinDemand(fid, idx)
            occupied += activeFunc.minDemand[i]
            if occupied > self.max_occupancy:
                return -1
        return cost

    # Best-fit will maximize this cost; worst-fit will minimize.
    def getCostFit(self, memIdx, activeFunc):
        cost = 0
        numAccesses = len(memIdx)
        for i in range(0, numAccesses):
            idx = memIdx[i]
            occupied = 0
            for fid in self.allocationMap[idx]:
                # determine amount of slack space available.
                cost += self.getMinDemand(fid, idx)
                occupied += self.getMinDemand(fid, idx)
            occupied += activeFunc.minDemand[i]
            if occupied > self.max_occupancy:
                return -1
        return cost

    # utility = normalized sum of fraction of max demand satisfied at each stage.
    # eg. utility=1 implies that the application got what it asked for.
    # assumes (actual) utility function is strictly increasing (wrt. memory).
    def getUtility(self, memIdx, activeFunc):
        utility = 0.0
        numAccesses = len(memIdx)
        sumMaxDemand = 0
        sumMaxBlocks = 0
        for i in range(0, numAccesses):
            idx = memIdx[i]
            maxDemand = activeFunc.minDemand[i] if activeFunc.minDemand[i] > 1 else self.max_occupancy
            sumMaxDemand += maxDemand
            fixed = 0
            numVar = 0
            for fid in self.allocationMap[idx]:
                if self.getMinDemand(fid, idx) > 1:
                    fixed += self.getMinDemand(fid, idx)
                else:
                    numVar += 1
            if activeFunc.minDemand[i] == 1:
                maxBlocks = math.floor((self.max_occupancy - fixed) / (numVar + 1))
            else:
                maxBlocks = min(self.max_occupancy - fixed - numVar, activeFunc.minDemand[i])
            if maxBlocks < activeFunc.minDemand[i]:
                return -1
            sumMaxBlocks += maxBlocks
        return (sumMaxBlocks * 1.0 / sumMaxDemand)

    # feasibility = if there are enough memory blocks to satisfy allocation.
    def getFeasibility(self, memIdx, activeFunc):
        numAccesses = len(memIdx)
        for i in range(0, numAccesses):
            idx = memIdx[i]
            occupied = 0
            for fid in self.allocationMap[idx]:
                occupied += self.getMinDemand(fid, idx)
            occupied += activeFunc.minDemand[i]
            if occupied > self.max_occupancy:
                return -1
        return 0

    def getCost(self, memIdx, activeFunc):
        cost = 0
        if self.metric == self.METRIC_COST:
            # cost = self.getCostMoving(memIdx, activeFunc)
            cost = self.getCostFit(memIdx, activeFunc)
        elif self.metric == self.METRIC_UTILITY:
            cost = self.getUtility(memIdx, activeFunc)
        elif self.metric == self.METRIC_UTILIZATION:
            cost = self.getUtilizationIncrease(memIdx, activeFunc)
        else:
            cost = self.getFeasibility(memIdx, activeFunc)
        return cost

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
        if self.DEBUG:
            print("=====CHANGES=====")
            print(currentSharing)
            print(sharing)
            print(self.revAllocationMap)
            print(revAllocationMap)
            print("=================")
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

    def computeNumChanges(self):
        numChanges = 0
        for j in range(0, self.num_stages):
            oldset = set()
            newset = set()
            for i in range(0, self.max_occupancy):
                if self.allocationMatrix[i, j] == 0:
                    continue
                oldset.add(self.allocationMatrix[i, j])
                newset.add(self.queue['allocationMatrix'][i, j])
            numChanges += len(newset) - len(oldset)
        return numChanges

    def computeAllocation(self, activeFunc, online=True):
        self.resetQueue()
        self.queue['fid'] = activeFunc.getFID()
        self.activeFuncs[activeFunc.getFID()] = activeFunc
        optCost = None
        optimal = None
        tsAllocStart = time.time()
        if online:
            enumeration = activeFunc.getEnumeration(transformed=True)
            for i in range(0, len(enumeration)):
                memIdx = enumeration[i]
                cost = self.getCost(memIdx, activeFunc)
                if cost < 0:
                    continue
                if not self.optimize:
                    optCost = cost
                    optimal = memIdx
                    break
                if optimal is None:
                    optCost = cost
                    optimal = memIdx
                if self.minimize and cost < optCost:
                    optCost = cost
                    optimal = memIdx
                elif not self.minimize and cost > optCost:
                    optCost = cost
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
                    optCost = cost
                    optimal = np.copy(current)
                if cost < optCost:
                    optCost = cost
                    optimal = np.copy(current)
                pos = radix - 1
                while pos >= 0 and current[pos] + 1 >= enumSizes[pos]:
                    pos = pos - 1
                if pos < 0:
                    break
                current[pos] = current[pos] + 1
                for i in range(pos + 1, radix):
                    current[i] = 0
        utilization = None
        allocation = None
        allocationMap = None
        if optimal is not None:
            if online:
                allocation = self.allocation.copy()
                allocationMap = copy.deepcopy(self.allocationMap)
                self.activeFuncs[activeFunc.getFID()].allocation = {}
                i = 0
                for idx in optimal:
                    allocation.add(idx)
                    allocationMap[idx].add(activeFunc.getFID())
                    self.activeFuncs[activeFunc.getFID()].allocation[idx] = i
                    i += 1
                utilization = self.getUtilization()
            else:
                allocation = set()
                allocationMap = {}
                # TODO update allocation for active function object.
                for i in range(0, self.num_stages):
                    allocationMap[i] = set()
                for i in range(0, radix):
                    variant = self.activeFuncs[fids[i]].getVariant(optimal[i])
                    for idx in variant:
                        allocation.add(idx)
                        allocationMap[idx].add(fids[i])
                optimal = variant
                utilization = self.getUtilization()
        tsAllocElapsed = time.time() - tsAllocStart
        if optCost is None:
            # allocation failed.
            optimal = None
            self.activeFuncs.pop(activeFunc.getFID())
        return (optimal, optCost, utilization, tsAllocElapsed, allocation, allocationMap)
    
    def computeAllocationMatrix(self, allocationMap):
        allocationMatrix = np.zeros((self.max_occupancy, self.num_stages), dtype=np.uint32)
        for i in range(0, self.num_stages):
            if len(allocationMap[i]) == 0:
                continue
            apps = [ (fid, self.activeFuncs[fid].wt, self.activeFuncs[fid].minDemand[self.activeFuncs[fid].allocation[i]]) for fid in allocationMap[i] ]
            sharing = len(apps)
            numBlocks = {}
            wtSum = 0
            maxWt = 0
            apps.sort(key=lambda x: x[0])
            # assuming ordered in increasing FID value.
            dominantFID = None
            sumBlocks = 0
            numElastic = 0
            remaining = self.max_occupancy
            # if apps have same weight, a random one is chosen as dominant.
            # random.shuffle(apps)
            # allocate number of blocks for inelastic apps first.
            for app in apps:
                fid = app[0]
                # only elastic apps can dominate.
                if app[2] == 1 and app[1] >= maxWt:
                    numElastic += 1
                    wtSum += app[1]
                    maxWt = app[1]
                    dominantFID = app[0]
                elif app[2] > 1:
                    numBlocks[fid] = app[2]
                    sumBlocks += numBlocks[fid]
                    remaining -= numBlocks[fid]
            # allocate number of blocks for elastic apps.
            elasticBlocks = remaining
            if numElastic > 0:
                if self.allocation_type == self.ALLOCATION_TYPE_MAXMINFAIR:
                    # max-min fairness.
                    assert(elasticBlocks >= numElastic)
                    while remaining > 0:
                        for app in apps:
                            fid = app[0]
                            # wt = app[1]
                            minDemand = app[2]
                            if minDemand > 1:
                                continue
                            if fid not in numBlocks:
                                numBlocks[fid] = 0
                            if remaining > 0:
                                numBlocks[fid] += 1
                                remaining -= 1
                else:
                    # default allocation.
                    for app in apps:
                        fid = app[0]
                        wt = app[1]
                        minDemand = app[2]
                        if minDemand > 1:
                            continue
                        if remaining <= 0:
                            print("Apps:", apps)
                            print("Assigned blocks", numBlocks)
                            sys.exit("Error[0]: out of memory!")
                        # in increasing order of weights (to avoid starvation of apps).
                        numBlocks[fid] = int(min(max(math.floor(wt * elasticBlocks / wtSum), minDemand), remaining))
                        sumBlocks += numBlocks[fid]
                        remaining -= numBlocks[fid]
                    if remaining < 0:
                        print("Assigned blocks", numBlocks)
                        sys.exit("Error: out of memory!")
                    # assign remaining to one with max weight or newest app (maximize utilization).
                    if dominantFID is not None:
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
            # verify that inelastic blocks are not reallocated.
            for k in range(0, self.max_occupancy):
                for j in range(0, i + 1):
                    fid = self.allocationMatrix[k, j]
                    if fid > 0:
                        """if (self.getMinDemand(fid, j) > 1 and fid != allocationMatrix[k, j]):
                            print("FID", fid, "Stage", j, "Current", i)
                            print(self.allocationMatrix)
                            print(allocationMatrix)
                            print(numBlocks)
                            print(apps)"""
                        assert not (self.getMinDemand(fid, j) > 1 and fid != allocationMatrix[k, j])
        return allocationMatrix

    def enqueueAllocation(self, allocation, allocationMap):
        allocationMatrix = self.computeAllocationMatrix(allocationMap)
        changes = self.computeChanges(allocationMap)
        if allocationMatrix is None:
            self.resetQueue()
            return (None, None)
        if self.DEBUG:
            print(allocationMatrix)
        remaps = {}
        updatedChanges = {}
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
                    if not (remap[0] == remap[1] and prevAlloc == newAlloc):
                        # inelastic apps should not be remapped/relocated within a stage.
                        assert not ((remap[0] == remap[1]) and self.activeFuncs[fid].minDemand[self.activeFuncs[fid].allocation[remap[0]]] > 1)
                        if fid not in updatedChanges:
                            updatedChanges[fid] = []
                        updatedChanges[fid].append(remap)
                        remaps[fid].append((remap[0], prevAlloc, remap[1], newAlloc))
                        if self.DEBUG:
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

        return (updatedChanges, remaps)

    def applyQueuedAllocation(self):
        if self.queue['fid'] is None:
            return
        self.allocation = copy.deepcopy(self.queue['allocation'])
        self.allocationMap = copy.deepcopy(self.queue['allocationMap'])
        self.revAllocationMap = copy.deepcopy(self.queue['revAllocationMap'])
        self.allocationMatrix = copy.deepcopy(self.queue['allocationMatrix'])
        self.resetQueue()

    def getAllocationBlocks(self, fid):
        allocation = {}
        for i in range(0, self.num_stages):
            blocks = []
            for j in range(0, self.max_occupancy):
                if self.allocationMatrix[j, i] == fid:
                    blocks.append(j)
            if len(blocks) > 0:
                allocation[i] = blocks
        return allocation

    def deallocate(self, fid):
        if fid not in self.activeFuncs:
            print("[allocator] FID %d not active." % fid)
            return
        for stageId in self.revAllocationMap[fid]:
            self.allocationMap[stageId].remove(fid)
            stageEmpty = True
            for i in range(0, self.max_occupancy):
                if self.allocationMatrix[i, stageId] == fid:
                    self.allocationMatrix[i, stageId] = 0
                elif self.allocationMatrix[i, stageId] > 0:
                    stageEmpty = False
            if stageEmpty:
                self.allocation.remove(stageId)
        self.revAllocationMap.pop(fid)
        self.activeFuncs.pop(fid)
        if self.DEBUG:
            print("[allocator] FID %d deallocated." % fid)