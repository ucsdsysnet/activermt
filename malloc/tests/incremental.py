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

def write_allocation_matrix(allocationMatrix, filename):
    with open(filename, "w") as out:
        out.write("\n".join([",".join([ str(y) for y in x ]) for x in allocationMatrix]))
        out.close()

optimize = True

memIdx = [2, 5]
applen = 10
iglim = 6

fid = 1
numAllocated = 0

allocator = Allocator(optimize=optimize, minimize=optimize)

programs = {}

while numAllocated < 9:
    program = ActiveFunction(fid, memIdx, iglim, applen, [1] * len(memIdx), enumerate=True)
    programs[fid] = program
    optimal,_,_,_, allocation, allocationMap = allocator.computeAllocation(program)
    if optimal is not None:
        allocator.enqueueAllocation(allocation, allocationMap)
        allocator.applyQueuedAllocation()
        numAllocated += 1
        fid += 1
        print("Allocated", numAllocated, "allocation", optimal)
    else:
        filled = True
        break

write_allocation_matrix(allocator.allocationMatrix, "allocation_matrix_original.csv")

fid = 3

baseFunc = programs[fid]
accessIdx = [6, 7]
minDemand = [1] * len(accessIdx)

allocationDelta = max(allocator.revAllocationMap[fid]) - max(baseFunc.constrLB)
baseProgLen = baseFunc.progLen + allocationDelta

# horizontal memory expansion.

progLen = baseProgLen + len(accessIdx)
igLim = -1
accessIdx += allocationDelta

program = ActiveFunction(Allocator.FID_AUGMENTATION, accessIdx, iglim, progLen, minDemand, enumerate=True)

optimal,_,_,_, allocation, allocationMap = allocator.computeAllocation(program)

assert(optimal is not None)

allocator.enqueueAllocation(allocation, allocationMap)
allocator.applyQueuedAllocation()
allocator.commitAugmentedAllocation(fid)

print("New allocation", optimal)

write_allocation_matrix(allocator.allocationMatrix, "allocation_matrix_expanded.csv")

# function augmentation.

fid = 4

baseFunc = programs[fid]
allocationDelta = max(allocator.revAllocationMap[fid]) - max(baseFunc.constrLB)
baseProgLen = baseFunc.progLen + allocationDelta

accessIdx = [3, 6]
minDemand = [1] * len(accessIdx)
igLim = -1
progLen = 9

accessIdx += baseProgLen - 1
progLen += baseProgLen - 1
igLim += baseProgLen - 1

program = ActiveFunction(Allocator.FID_AUGMENTATION, accessIdx, iglim, progLen, minDemand, enumerate=True)

optimal,_,_,_, allocation, allocationMap = allocator.computeAllocation(program)

assert(optimal is not None)

allocator.enqueueAllocation(allocation, allocationMap)
allocator.applyQueuedAllocation()
allocator.commitAugmentedAllocation(fid)

print("New allocation", optimal)

write_allocation_matrix(allocator.allocationMatrix, "allocation_matrix_augmented.csv")