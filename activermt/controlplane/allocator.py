#!/usr/bin/python3

#    Copyright 2023 Rajdeep Das, University of California San Diego.

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#        http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

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
    def __init__(self, fid, accessIdx, igLim, progLen, minDemand, weight=1, enumerate=False, allow_filling=False):
        assert len(accessIdx) == len(minDemand)
        # assert progLen <= 20
        self.debug = False
        self.allow_recirculations = allow_filling
        self.num_stages = 20
        self.num_stage_ig = 10
        self.num_stage_eg = self.num_stages - self.num_stage_ig
        self.fid = fid
        self.wt = weight
        self.igLim = igLim
        self.progLen = progLen
        self.minDemand = minDemand
        self.accessIdx = copy.deepcopy(accessIdx)
        self.numUnique = len(self.accessIdx)
        # ensuring re-circulation cost does not increase.
        self.computeConstraints()
        if self.debug:
            print("[DEBUG] Maximum program length:", self.maxProgLen)
            print("[DEBUG] Constraint (UB):")
            print(self.constrUB)
        self.allocation = None
        self.enumeration = []
        self.enumTime = None
        if enumerate:
            self.enumerate()

    def computeConstraints(self):
        self.maxProgLen = max(self.progLen if self.progLen <= self.num_stages else self.num_stage_ig + int(math.ceil((self.progLen - self.num_stage_ig) * 1.0 / self.num_stage_eg) * self.num_stage_eg), self.num_stages)
        if self.allow_recirculations:
            self.maxProgLen += self.num_stage_eg
        self.numAccesses = len(self.accessIdx)
        self.A = self.getDeltaMatrix(self.numAccesses)
        self.constrLB = np.copy(self.accessIdx).astype('uint32')
        self.constrUB = self.constrLB + self.maxProgLen - self.progLen - 1
        # self.constrUB = self.constrLB + self.num_stages - self.progLen - 1
        # self.constrUB = self.constrLB + self.num_stages - self.progLen + 1
        if self.igLim >= 0 and self.igLim < self.num_stage_ig:
            for i in range(0, self.numAccesses):
                if self.constrLB[i] < self.igLim:
                    self.constrUB[i] = self.constrLB[i] + self.num_stage_ig - self.igLim - 1
        self.constrDelta = np.matmul(self.A, self.constrLB)

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
        orig = [ (y if y < self.num_stage_ig else y % self.num_stage_eg + self.num_stage_ig) for y in self.constrLB ]
        reuses = {}
        idx = 0
        for m in orig:
            if m not in reuses:
                reuses[m] = []
            reuses[m].append(idx)
            idx += 1
        recircs = []
        for m in reuses:
            if len(reuses[m]) > 1:
                recircs.append((m, reuses[m]))
        self.numUnique = len(reuses.keys())
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
            valid = True
            # preserve recirculation-based accesses.
            for r in recircs:
                idx = r[1]
                for i in range(1, len(idx)):
                    if x[idx[i]] != x[idx[i - 1]]:
                        valid = False
            if len(np.unique(x)) == self.numUnique and valid:
                pruned.append(enum)
        self.enumeration = pruned
        tsEnumEnd = time.time()
        self.enumTime = tsEnumEnd - tsEnumStart

    def getVariant(self, idx, transformed=False):
        if idx < len(self.enumeration):
            if not transformed:
                return self.enumeration[idx]
            else:
                return (np.unique([ (y if y < self.num_stage_ig else y % self.num_stage_eg + self.num_stage_ig) for y in self.enumeration[idx] ]))
        return None

    def getEnumeration(self, transformed=False):
        if transformed:
            transformed = []
            for enum in self.enumeration:
                x = [ (y if y < self.num_stage_ig else y % self.num_stage_eg + self.num_stage_ig) for y in enum ]
                # if len(np.unique(x)) == self.numUnique:
                transformed.append(np.unique(x))
            return transformed
        return self.enumeration

# allocator

class Allocator:

    METRIC_COST = 0
    METRIC_UTILITY = 1
    METRIC_UTILIZATION = 2
    METRIC_SAT = 3
    METRIC_REALLOC = 4
    # ALLOCATION_GRANULARITY = 368
    ALLOCATION_TYPE_DEFAULT = 0
    ALLOCATION_TYPE_MAXMINFAIR = 1
    NUM_STAGES = 20
    FID_AUGMENTATION = 253
    WT_OVERFLOW = 1000000

    def __init__(self, metric=0, optimize=True, minimize=True, debug=False, granularity=368):
        self.num_stages = self.NUM_STAGES
        self.ALLOCATION_GRANULARITY = granularity
        self.max_occupancy = self.ALLOCATION_GRANULARITY
        self.metric = metric
        self.optimize = optimize
        self.minimize = minimize
        self.allocation_type = self.ALLOCATION_TYPE_MAXMINFAIR
        self.DEBUG = debug
        self.allocationMatrix = None
        self.elastic_offset = [0] * self.num_stages
        self.fragmentation = [[]] * self.num_stages
        self.reset()
        self.profiling = {
            'getCost'   : [],
            'enums'     : []
        }

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
        assert(fid in self.activeFuncs)
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

    # occupancy = number of active applications.
    def getOccupancy(self):
        return len(self.activeFuncs.keys())

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

    # cost = amount of data moving required to accomodate new app.
    # determined by number of elastic applications residing in particular stage.
    # progressive filling consideration required to find exact cost.
    def getCostMoving(self, memIdx, activeFunc, exact=True):
        cost = 0
        numAccesses = len(memIdx)
        for i in range(0, numAccesses):
            idx = memIdx[i]
            occupied = 0
            num_elastic = 0
            inelastic_region = 0
            stage_cost = 0
            # 1. find number of elastic apps and available memory region.
            for fid in self.allocationMap[idx]:
                # pessimistic estimate.
                if self.getMinDemand(fid, idx) == 1:
                    stage_cost += 1
                    num_elastic += 1
                occupied += self.getMinDemand(fid, idx)
                if self.getMinDemand(fid, idx) > 1:
                    inelastic_region += self.getMinDemand(fid, idx)
            occupied += activeFunc.minDemand[i]
            # check if there is enough space to accomodate new app.
            if occupied > self.max_occupancy:
                return -1
            if activeFunc.minDemand[i] == 1:
                elastic_region = self.max_occupancy - self.elastic_offset[idx]
                if num_elastic + 1 > elastic_region:
                    return -1
            else:
                largest_cluster = self.max_occupancy - self.elastic_offset[idx]
                # if (largest_cluster - activeFunc.minDemand[i]) < num_elastic:
                #     return -1
                if len(self.fragmentation[idx]) > 0 and self.fragmentation[idx][0][1] > largest_cluster:
                    largest_cluster = self.fragmentation[idx][0][1]
                elif (largest_cluster - activeFunc.minDemand[i]) < num_elastic:
                    return -1
                if largest_cluster < activeFunc.minDemand[i]:
                    return -1
            if exact:
                # 2. estimate filled cost.
                elastic_region = self.max_occupancy - inelastic_region
                if activeFunc.minDemand[i] == 1 and num_elastic > 0:
                    # compute how may elastic apps are affected.
                    num_elastic += 1
                    # cost function: 
                    # f(x) =    x - 1                   , if floor(N/x) < floor(N/(x-1))
                    #           (N % (x-1)) - (N % x)   , otherwise
                    # where N is the number of memory blocks in elastic region, x is the number of elastic apps.
                    # stage_cost = num_elastic - 1 if math.floor(elastic_region / num_elastic) < math.floor(elastic_region / (num_elastic - 1)) else (elastic_region % (num_elastic - 1)) - (elastic_region % num_elastic)
                    # f(x) =    x - 1                   , if floor(N/x) < floor(N/(x-1))
                    #           N - 1 - (N % x)   , otherwise
                    # where N is the number of memory blocks in elastic region, x is the number of elastic apps.
                    stage_cost = num_elastic - 1 if math.floor(elastic_region / num_elastic) < math.floor(elastic_region / (num_elastic - 1)) else num_elastic - (elastic_region % num_elastic) - 1
                    # blocks = np.zeros((num_elastic, 2), dtype=np.int)
                    # n = elastic_region
                    # while n > 0:
                    #     for j in range(0, num_elastic - 1):
                    #         blocks[j, 0] += 1
                    #         n -= 1
                    #         if n == 0:
                    #             break
                    # n = elastic_region
                    # while n > 0:
                    #     for j in range(0, num_elastic):
                    #         blocks[j, 1] += 1
                    #         n -= 1
                    #         if n == 0:
                    #             break
                    # stage_cost = 0
                    # for j in range(0, num_elastic - 1):
                    #     print(blocks[j, 0], blocks[j, 1])
                    #     stage_cost += 1 if blocks[j, 0] != blocks[j, 1] else 0
                else:
                    # inelastic applications are pinned to beginning of memory region.
                    stage_cost = num_elastic
            cost += stage_cost
        return cost

    # Best-fit will maximize this cost; worst-fit will minimize.
    def getCostFit(self, memIdx, activeFunc):
        # conditions:
        # 1. inelastic app should fit.
        # 2. elastic app should fit.
        # 3. remaining blocks after fitting is inverse of cost.
        # (Does not attempt to find the allocated region.)
        sumcost = 0
        numAccesses = len(memIdx)
        for i in range(0, numAccesses):
            idx = memIdx[i]
            cost = 0
            num_elastic = 0
            # min requirements; number of blocks left after satisfying min demands is the cost.
            for fid in self.allocationMap[idx]:
                cost += self.getMinDemand(fid, idx)
                if self.getMinDemand(fid, idx) == 1:
                    num_elastic += 1
            cost += activeFunc.minDemand[i]
            if cost > self.max_occupancy:
                return -1
            # separate logic for elastic/inelastic.
            if activeFunc.minDemand[i] == 1:
                elastic_region = self.max_occupancy - self.elastic_offset[idx]
                if num_elastic + 1 > elastic_region:
                    return -1
                # elastic applications do not benefit from fragmentation; cost is (based on) proportion of total memory elastic app gets.
                # estimates (elastic) tenancy as cost, to factor in reallocations.
                cost = num_elastic * (self.max_occupancy * 1.0 / elastic_region)
                num_elastic += 1
            else:
                largest_cluster = self.max_occupancy - self.elastic_offset[idx]
                # check if existing elastic apps can fit.
                # if (largest_cluster - activeFunc.minDemand[i]) < num_elastic:
                #     return -1
                if len(self.fragmentation[idx]) > 0 and self.fragmentation[idx][0][1] > largest_cluster:
                    largest_cluster = self.fragmentation[idx][0][1]
                elif (largest_cluster - activeFunc.minDemand[i]) < num_elastic:
                    return -1
                # check if inelastic app can fit.
                if largest_cluster < activeFunc.minDemand[i]:
                    return -1
            assert(self.max_occupancy - self.elastic_offset[idx] >= num_elastic)
            sumcost += cost
        return sumcost

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
        elif self.metric == self.METRIC_REALLOC:
            cost = self.getCostMoving(memIdx, activeFunc)
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
    
    def buildAllocationMatrix(self, fids, variants, af):
        allocation_map = {}
        for stage in range(0, self.num_stages):
            allocation_map[stage] = set()
        for id in range(0, len(variants) - 1):
            variant = self.activeFuncs[fids[id]].getVariant(variants[id], transformed=True)
            print("variant: ", variant)
            for stage in variant:
                allocation_map[stage].add(fids[id])
        for stage in af.getVariant(variants[-1], transformed=True):
            allocation_map[stage].add(af.fid)
        # matrix = self.computeAllocationMatrix(allocation_map)
        return None
    
    def getBenefitUtilization(self, fids, X, af):
        allocation_matrix = self.buildAllocationMatrix(fids, X, af)
        utilization = 0.0
        numBlocksTotal = self.max_occupancy * self.num_stages
        for i in range(0, self.max_occupancy):
            for j in range(0, self.num_stages):
                utilization += 1 if allocation_matrix[i, j] > 0 else 0
        return (utilization * 1.0 / numBlocksTotal)

    def getCostReallocations(self, fids, X, af):
        allocation_matrix = self.buildAllocationMatrix(fids, X, af)
        ws_old = set(np.unique(self.allocationMatrix))
        reallocated = set()
        for i in range(self.max_occupancy):
            for j in range(self.num_stages):
                fid = allocation_matrix[i, j]
                if fid == 0 or fid not in ws_old:
                    continue
                if self.allocationMatrix[i, j] != allocation_matrix[i, j]:
                    reallocated.add(fid)
        return len(reallocated)

    def getOccupancyCost(self, fids, X, af):
        occupancy = np.zeros((self.num_stages, 1), dtype=np.uint32)
        for i in range(0, len(X) - 1):
            variant = self.activeFuncs[fids[i]].getVariant(X[i], transformed=True)
            for stage in variant:
                occupancy[stage] += 1
        for stage in af.getVariant(X[-1], transformed=True):
            occupancy[stage] += 1
        return np.sum(np.square(occupancy))

    def computeAllocation(self, activeFunc, online=True):
        self.resetQueue()
        self.queue['fid'] = activeFunc.getFID()
        self.activeFuncs[activeFunc.getFID()] = activeFunc
        optCost = None
        optimal = None
        enumTime = 0
        ppTime = 0
        searchTime = 0
        tsAllocStart = time.time()
        if online:
            enum_start = time.time()
            enumeration = activeFunc.getEnumeration(transformed=True)
            enum_end = time.time()
            enumTime = enum_end - enum_start
            self.profiling['enums'].append(len(enumeration))
            search_start = time.time()
            for i in range(0, len(enumeration)):
                memIdx = enumeration[i]
                t1 = time.time()
                cost = self.getCost(memIdx, activeFunc)
                t2 = time.time()
                self.profiling['getCost'].append(t2 - t1)
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
            search_end = time.time()
            searchTime = search_end - search_start
        else:
            enumSizes = []
            fids = []
            for fid in self.activeFuncs:
                fids.append(fid)
                enumSizes.append(self.activeFuncs[fid].getEnumerationSize())
            radix = len(fids)
            rng = np.random.default_rng()
            max_iter = 1000
            optimal_value = np.inf
            optimal = None
            for iter in range(0, max_iter):
                X = []
                for i in range(0, radix):
                    varidx = int(rng.random() * enumSizes[i])
                    X.append(varidx)
                varidx = int(rng.random() * activeFunc.getEnumerationSize())
                X.append(varidx)
                value = self.getOccupancyCost(fids, X, activeFunc)
                # assumes that the cost is always minimized.
                if value < optimal_value:
                    optimal_value = value
                    optimal = np.copy(X)
            optCost = optimal_value
        utilization = None
        allocation = None
        allocationMap = None
        if optimal is not None:
            if online:
                pp_start = time.time()
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
                pp_end = time.time()
                ppTime = pp_end - pp_start
            else:
                allocation = set()
                allocationMap = {}
                # TODO update allocation for active function object.
                for fid in self.activeFuncs:
                    self.activeFuncs[fid].allocation = {}
                self.activeFuncs[activeFunc.getFID()].allocation = {}
                for i in range(0, self.num_stages):
                    allocationMap[i] = set()
                for i in range(0, radix):
                    variant = self.activeFuncs[fids[i]].getVariant(optimal[i], transformed=True)
                    k = 0
                    for idx in variant:
                        allocation.add(idx)
                        allocationMap[idx].add(fids[i])
                        self.activeFuncs[fids[i]].allocation[idx] = k
                        k += 1
                k = 0
                for idx in activeFunc.getVariant(optimal[-1], transformed=True):
                    allocation.add(idx)
                    allocationMap[idx].add(activeFunc.getFID())
                    self.activeFuncs[activeFunc.getFID()].allocation[idx] = k
                    k += 1
                optimal = activeFunc.getVariant(optimal[-1], transformed=True)
                utilization = self.getUtilization()
        tsAllocElapsed = time.time() - tsAllocStart
        if optCost is None:
            # allocation failed.
            optimal = None
            self.activeFuncs.pop(activeFunc.getFID())
        return (optimal, optCost, utilization, tsAllocElapsed, allocation, allocationMap, enumTime, searchTime, ppTime)
    
    def computeAllocationMatrix(self, allocationMap):
        allocationMatrix = np.zeros((self.max_occupancy, self.num_stages), dtype=np.uint32)
        allocation_stages = []
        for i in range(0, self.num_stages):
            if len(allocationMap[i]) == 0:
                continue
            current_tenants = set()
            for j in range(0, self.max_occupancy):
                if self.allocationMatrix[j, i] != 0:
                    current_tenants.add(self.allocationMatrix[j, i])
            current_inelastic_tenants = set()
            current_elastic_tenants = set()
            # copy the allocation for the inelastic applications.
            frag_start = -1
            frag_end = -1
            self.fragmentation[i] = []
            for j in range(0, self.elastic_offset[i]):
                assert (self.allocationMatrix[j, i] == 0 or self.getMinDemand(self.allocationMatrix[j, i], i) > 1),"unexpected elastic app in elastic region: {}".format(self.allocationMatrix[j, i])
                allocationMatrix[j, i] = self.allocationMatrix[j, i]
                if self.allocationMatrix[j, i] != 0 and self.getMinDemand(self.allocationMatrix[j, i], i) > 1:
                    current_inelastic_tenants.add(self.allocationMatrix[j, i])
                if self.allocationMatrix[j, i] == 0 or self.getMinDemand(self.allocationMatrix[j, i], i) == 1:
                    if frag_start < 0:
                        frag_start = j
                    else:
                        frag_end = j
                elif frag_start >= 0:
                    frag_end = frag_start if frag_end < 0 else frag_end
                    num_frag_blocks = frag_end - frag_start + 1
                    self.fragmentation[i].append((frag_start, num_frag_blocks))
                    frag_start = -1
            for j in range(self.elastic_offset[i], self.max_occupancy):
                if self.allocationMatrix[j, i] != 0 and self.getMinDemand(self.allocationMatrix[j, i], i) == 1:
                    current_elastic_tenants.add(self.allocationMatrix[j, i])
            # apps = [ (fid, self.activeFuncs[fid].wt, self.activeFuncs[fid].minDemand[self.activeFuncs[fid].allocation[i]]) for fid in allocationMap[i] ]
            apps = [ (fid, self.activeFuncs[fid].wt, self.getMinDemand(fid, i)) for fid in allocationMap[i] ]
            arrivals = list(filter(lambda x: (x[0] not in current_tenants), apps))
            assert (len(arrivals) <= 1),"too many concurrent arrivals on stage {}: {},{}".format(i, arrivals,current_tenants)
            # no new arrivals for this stage.
            # if len(arrivals) == 0:
            #     continue
            allocation_stages.append(i)
            numElastic = 0
            numInelastic = 0
            # prune allocation set.
            pruned_apps = []
            for app in apps:
                fid = app[0]
                demand = app[2]
                if fid not in current_inelastic_tenants:
                    pruned_apps.append(app)
                if demand == 1:
                    numElastic += 1
            inelasticArrivals = list(filter(lambda x: (x[2] > 1), pruned_apps))
            elasticArrivals = list(filter(lambda x: (x[2] == 1 and x[0] not in current_elastic_tenants), pruned_apps))
            assert (len(inelasticArrivals) <= 1),"too many concurrent inelastic arrivals: {}".format(inelasticArrivals)
            assert (len(elasticArrivals) <= 1),"too many concurrent elastic arrivals: {}".format(elasticArrivals)
            apps = pruned_apps
            # assuming ordered in increasing FID value.
            apps.sort(key=lambda x: x[0])
            assert (self.max_occupancy - self.elastic_offset[i] >= numElastic),"overlimit: {} app arrival w/ demand={}".format("elastic" if len(inelasticArrivals) == 0 else "inelastic", 1 if len(inelasticArrivals) == 0 else inelasticArrivals[0][2])
            # 1. ALLOCATE blocks for inelastic apps first.
            for app in apps:
                fid = app[0]
                demand = app[2]
                if demand > 1:
                    # Cases:
                    # 1. FF
                    # 2. BF
                    # 3. WF
                    # find largest fragmented hole.
                    fraghole = None
                    fragIdx = None
                    for k in range(0, len(self.fragmentation[i])):
                        frag = self.fragmentation[i][k]
                        if frag[1] < demand:
                            continue
                        # TODO: depends on fit.
                        if fraghole is None or frag[1] > fraghole[1]:
                            fraghole = frag
                            fragIdx = k
                    # fill up a fragmented hole if possible.
                    if fraghole is None:
                        for j in range(0, demand):
                            allocationMatrix[self.elastic_offset[i] + j, i] = fid
                        self.elastic_offset[i] += demand
                    else:
                        for j in range(0, demand):
                            allocationMatrix[fraghole[0] + j, i] = fid
                        if demand == fraghole[1]:
                            self.fragmentation[i].pop(fragIdx)
                        else:
                            self.fragmentation[i][fragIdx] = (self.fragmentation[i][fragIdx][0] + demand, self.fragmentation[i][fragIdx][1] - demand)
                    numInelastic += 1
            remaining = self.max_occupancy - self.elastic_offset[i]
            # for frag in self.fragmentation[i]:
            #     remaining += frag[1]
            # 2. ALLOCATE number of blocks for elastic apps.
            elasticBlocks = remaining
            numBlocks = {}
            clusters = {}
            app_fids = []
            # fragments = copy.deepcopy(self.fragmentation[i])
            fragments = []
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
                    fragments.append((self.elastic_offset[i], self.max_occupancy - self.elastic_offset[i]))
                    # print("numblocks", numBlocks)
                    app_fids = list(numBlocks.keys())
                    current = 0
                    nonEmpty = 0
                    for k in range(0, len(fragments)):
                        frag = fragments[k]
                        fragment_id = frag[0]
                        if fragment_id not in clusters:
                            clusters[fragment_id] = []
                        cluster_size = frag[1]
                        while cluster_size > 0 and current < numElastic:
                            nblocks = numBlocks[app_fids[current]]
                            if cluster_size >= nblocks:
                                clusters[fragment_id].append((nblocks, current))
                                cluster_size -= nblocks
                                current += 1
                            else:
                                break
                        fragments[k] = (fragments[k][0], cluster_size)
                        nonEmpty += 1 if cluster_size > 0 else 0
                    fragments.sort(key=lambda x: -x[1])
                    # print("fragments", fragments)
                    # print("clusters[_]", clusters)
                    assert(numElastic - current <= nonEmpty)
                    for k in range(0, len(fragments)):
                        if current >= numElastic:
                            break
                        frag = fragments[k]
                        fragment_id = frag[0]
                        nblocks = frag[1]
                        if nblocks == 0:
                            continue
                        clusters[fragment_id].append((nblocks, current))
                        current += 1
                        fragments[k] = (fragments[k][0], 0)
                    # print("clusters", clusters)
                else:
                    # default allocation.
                    raise Exception("Default allocation not implemented!")
            # update the allocation matrix.
            for frag in fragments:
                clusterId = frag[0]
                if clusterId not in clusters:
                    continue
                offset = clusterId
                allocations = clusters[clusterId]
                for allocation in allocations:
                    fid = app_fids[allocation[1]]
                    nblocks = allocation[0]
                    for k in range(0, nblocks):
                        allocationMatrix[k + offset, i] = fid
                    offset += nblocks
            self.fragmentation[i].sort(key=lambda x: -x[1])
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
            # verify that existing allocations are retained.
            ws = set()
            for k in range(0, self.max_occupancy):
                if allocationMatrix[k, j] > 0:
                    ws.add(allocationMatrix[k, j])
            assert len(current_tenants.difference(ws)) == 0,"some existing allocations were lost."
            # verify that new allocations are performed.
            for app in arrivals:
                assert (app[0] in ws),"some new allocations were not performed."
        assert (len(allocation_stages) > 0),"no allocations were performed."
        return allocationMatrix

    def enqueueAllocation(self, allocation, allocationMap):
        allocationMatrix = self.computeAllocationMatrix(allocationMap)

        elastic_apps = set()

        # mod
        comparison = {}
        for i in range(0, self.num_stages):
            for k in range(0, self.max_occupancy):
                fid = self.allocationMatrix[k, i]
                if fid > 0:
                    assert not (self.getMinDemand(fid, i) > 1 and fid != allocationMatrix[k, i])
                    if self.getMinDemand(fid, i) == 1:
                        elastic_apps.add(fid)
                        if fid not in comparison:
                            comparison[fid] = {
                                'old'   : set(),
                                'new'   : set()
                            }
                        comparison[fid]['old'].add((i, k))
        for i in range(0, self.num_stages):
            for k in range(0, self.max_occupancy):
                fid = allocationMatrix[k, i]
                if fid > 0:
                    if self.getMinDemand(fid, i) == 1:
                        if fid not in comparison:
                            continue
                        comparison[fid]['new'].add((i, k))
        
        diff = {}
        for fid in comparison:
            removed = comparison[fid]['old'].difference(comparison[fid]['new'])
            added = comparison[fid]['new'].difference(comparison[fid]['old'])
            if len(removed) > 0 or len(added) > 0:
                diff[fid] = (removed, added)

        # mapping from FID to (old_stage,new_stage,is_resized)
        changes = {}
        for fid in diff:
            removed = diff[fid][0]
            #added = diff[fid][1]
            affected_stages = set()
            for r in removed:
                stage_id = r[0]
                affected_stages.add(stage_id)
            for stage_id in affected_stages:
                if fid not in changes:
                    changes[fid] = []
                changes[fid].append((stage_id, stage_id, True))

        # print(changes)
        
        # changes = self.computeChanges(allocationMap)
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

        # print(remaps.keys())

        num_elastic_apps = len(elastic_apps)

        return (changes, remaps, num_elastic_apps)

    def applyQueuedAllocation(self):
        if self.queue['fid'] is None:
            return False
        self.allocation = copy.deepcopy(self.queue['allocation'])
        self.allocationMap = copy.deepcopy(self.queue['allocationMap'])
        self.revAllocationMap = copy.deepcopy(self.queue['revAllocationMap'])
        self.allocationMatrix = copy.deepcopy(self.queue['allocationMatrix'])
        self.resetQueue()
        return True

    def commitAugmentedAllocation(self, fid):
        if self.FID_AUGMENTATION in self.allocation:
            self.allocation.remove(self.FID_AUGMENTATION)
        for stageId in self.allocationMap:
            if self.FID_AUGMENTATION in self.allocationMap[stageId]:
                self.allocationMap[stageId].remove(self.FID_AUGMENTATION)
                if fid not in self.allocationMap[stageId]:
                    self.allocationMap[stageId].add(fid)
        if self.FID_AUGMENTATION in self.revAllocationMap:
            stages = self.revAllocationMap[self.FID_AUGMENTATION]
            if fid not in self.revAllocationMap:
                raise Exception("FID %d not in allocation map!" % fid)
            for stageId in stages:
                self.revAllocationMap[fid].append(stageId)
            self.revAllocationMap.pop(self.FID_AUGMENTATION)
        for i in range(0, self.NUM_STAGES):
            for j in range(0, self.ALLOCATION_GRANULARITY):
                if self.allocationMatrix[j, i] == self.FID_AUGMENTATION:
                    self.allocationMatrix[j, i] = fid 
        assert(fid in self.activeFuncs)
        augFunc = self.activeFuncs[self.FID_AUGMENTATION]
        self.activeFuncs[fid].progLen = augFunc.progLen
        self.activeFuncs[fid].igLim = augFunc.igLim
        self.activeFuncs[fid].accessIdx = np.append(self.activeFuncs[fid].accessIdx, augFunc.accessIdx)
        self.activeFuncs[fid].minDemand = np.append(self.activeFuncs[fid].minDemand, augFunc.minDemand)
        for idx in augFunc.allocation:
            self.activeFuncs[fid].allocation[idx] = augFunc.allocation[idx]
        self.activeFuncs[fid].computeConstraints()
        self.activeFuncs.pop(self.FID_AUGMENTATION)

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

    def getAllocationBlocksRange(self, fid):
        allocation = self.getAllocationBlocks(fid)
        allocation_range = {}
        for stageId in allocation:
            # blocks are currently contiguous.
            allocation_range[stageId] = (allocation[stageId][0], allocation[stageId][-1])
        return allocation_range

    def deallocate(self, fid):
        if fid not in self.activeFuncs:
            if self.DEBUG:
                print("[allocator] FID %d not active." % fid)
            return False
        for stageId in self.revAllocationMap[fid]:
            isElastic = (self.getMinDemand(fid, stageId) == 1)
            self.allocationMap[stageId].remove(fid)
            stageEmpty = True
            numBlocksRemoved = 0
            lastBlockRemoved = -1
            for i in range(0, self.max_occupancy):
                if self.allocationMatrix[i, stageId] == fid:
                    self.allocationMatrix[i, stageId] = 0
                    numBlocksRemoved += 1
                    lastBlockRemoved = i
                elif self.allocationMatrix[i, stageId] > 0:
                    stageEmpty = False
            if stageEmpty:
                assert(stageId in self.allocation)
                self.allocation.remove(stageId)
            if not isElastic:
                if (lastBlockRemoved + 1) == self.elastic_offset[stageId]:
                    self.elastic_offset[stageId] -= numBlocksRemoved
                else:
                    firstBlockRemoved = lastBlockRemoved - numBlocksRemoved + 1
                    self.fragmentation[stageId].append((firstBlockRemoved, numBlocksRemoved))
                    # TODO coalese adjacent blocks when possible.
                    # self.fragmentation[stageId].sort(key=lambda x: x[0])
                    # for k in range(1, len(self.fragmentation[stageId])):
                    #     pass
        self.revAllocationMap.pop(fid)
        self.activeFuncs.pop(fid)
        if self.DEBUG:
            print("[allocator] FID %d deallocated." % fid)
        return True