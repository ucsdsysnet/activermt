function [minOverlaps, variant, numTrials] = onlineAllocationBrute(progLen,memAccessIdx,currentAllocation)
    NUM_STAGES = 20;
    constrLB = memAccessIdx;
    constrUB = constrLB + (NUM_STAGES - progLen);
    
    numAccesses = length(constrLB);
    
    A = zeros(numAccesses);
    A(1, 1) = 1;
    for r = 2:numAccesses
        A(r, r - 1) = -1;
        A(r, r) = 1;
    end
    
    constrDelta = A * constrLB';
    
    memidxBase = constrUB - constrLB + 1;
    memidxRange = prod(memidxBase);
    
    allocBitMap = zeros(1, NUM_STAGES);
    allocBitMap(currentAllocation) = 1;
    
    variant = zeros(numAccesses, 1);
    numTrials = 0;
    minOverlaps = -1;
    minOverlapVariant = zeros(numAccesses, 1);
    for i = 1:memidxRange
        numTrials = numTrials + 1;
        eidx = i - 1;
        j = 1;
        while eidx > 0 && j <= numAccesses
            offset= mod(eidx, memidxBase(j));
            variant(j) = constrLB(j) + offset;
            eidx = floor(eidx / memidxBase(j));
            j = j + 1;
        end
        pfx = A * variant;
        numOverlaps = -1;
        if all(pfx >= constrDelta)
            allocation = zeros(1, NUM_STAGES);
            allocation(variant) = 1;
            numOverlaps = dot(allocBitMap, allocation);
        end
        if numOverlaps == 0
            break
        elseif minOverlaps == -1 || numOverlaps < minOverlaps
            minOverlapVariant(:) = variant(:);
            minOverlaps = numOverlaps;
        end
    end
    if numOverlaps > 0
        variant = minOverlapVariant;
    end
end