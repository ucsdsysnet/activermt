#!/usr/bin/python3

import os
import sys
import numpy as np

sys.path.insert(0, os.path.pardir)

from allocator import *

def print_allocated_blocks(allocationMatrix, stageId):
    allocatedBlocks = []
    for i in range(0, Allocator.ALLOCATION_GRANULARITY):
        allocatedBlocks.append(allocationMatrix[i, stageId])
    print(str(allocatedBlocks))

def compute_fairness_index(allocationMatrix, allocator, stageId):
    numBlocks = {}
    for i in range(0, Allocator.ALLOCATION_GRANULARITY):
        fid = allocationMatrix[i, stageId]
        if fid == 0 or allocator.getMinDemand(fid, stageId) > 1:
            continue
        if fid not in numBlocks:
            numBlocks[fid] = 0
        numBlocks[fid] += 1
    allocations = np.array(list(numBlocks.values()))
    fairness_index = (np.sum(allocations)**2) / (len(allocations) * np.sum(np.square(allocations)))
    return fairness_index

optimize = True

memIdx = [2]
applen = 10
iglim = 9

allocator = Allocator(optimize=optimize, minimize=optimize)

filled = False
numAllocated = 0
fid = 1

# allocate inelastic apps first.
while not filled and numAllocated < 1000:
    program = ActiveFunction(fid, memIdx, iglim, applen, [6] * len(memIdx), enumerate=True)
    assert(len(program.getEnumeration()) == 1)
    optimal,_,_,_, allocation, allocationMap = allocator.computeAllocation(program)
    if optimal is not None:
        allocator.enqueueAllocation(allocation, allocationMap)
        allocator.applyQueuedAllocation()
        numAllocated += 1
        fid += 1
        print("Allocated", numAllocated)
    else:
        filled = True
        break

print_allocated_blocks(allocator.allocationMatrix, 2)

# create fragments in allocation matrix.
fid_start = 10
for i in range(0, 6):
    fragid = fid_start + i
    print("Deallocating", fragid)
    allocator.deallocate(fragid)

print_allocated_blocks(allocator.allocationMatrix, 2)

print(allocator.fragmentation)

filled = False
fairness = []

# allocate elastic apps.
while not filled and numAllocated < 1000:
    program = ActiveFunction(fid, memIdx, iglim, applen, [1] * len(memIdx), enumerate=True)
    assert(len(program.getEnumeration()) == 1)
    optimal,_,_,_, allocation, allocationMap = allocator.computeAllocation(program)
    if optimal is not None:
        allocator.enqueueAllocation(allocation, allocationMap)
        allocator.applyQueuedAllocation()
        numAllocated += 1
        fid += 1
        fairness.append(compute_fairness_index(allocator.allocationMatrix, allocator, 2))
        print("Allocated", numAllocated)
        # print_allocated_blocks(allocator.allocationMatrix, 2)
    else:
        filled = True
        print("Cannot allocate any more apps.")
        break

print_allocated_blocks(allocator.allocationMatrix, 2)

with open("fairness_indices.csv", "w") as f:
    f.write("\n".join([str(x) for x in fairness]))
    f.close()