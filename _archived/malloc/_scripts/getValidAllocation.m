function [allocation, minCost] = getValidAllocation(numInstances, midx, constrMaxStage, plen, baseAllocation)
    NUM_STAGES = 20;

    baseAllocation = [baseAllocation; zeros(1, NUM_STAGES)];
    
    c = ones(numInstances, 1);
    sMax = ones(NUM_STAGES, 1);
    
    numMutants = zeros(numInstances, 1);
    M = [];

    for j = 1:numInstances
        mutants = generateMutants(plen, midx, constrMaxStage);
        numMutants(j) = size(mutants, 2);
        M = [M; mutants'];
    end

    enumSize = 1;
    for i = 1:length(numMutants)
        enumSize = enumSize * numMutants(i);
    end

    minCost = NUM_STAGES^2;
    
    for i = 1:enumSize
        cfg = zeros(numInstances, 1);
        eidx = i - 1;
        j = 1;
        while eidx > 0 && j <= length(numMutants)
            cfg(j) = mod(eidx, numMutants(j));
            eidx = floor(eidx / numMutants(j));
            j = j + 1;
        end
        cfg = cfg + 1;
        D = zeros(numInstances, NUM_STAGES);
        preSum = 0;
        for j = 1:numInstances
            xidx = preSum + cfg(j);
            demand = M(xidx, : );
            D(j, : ) = demand;
            preSum = sum(numMutants(1:j));
        end
        d = c' * D;
        validM = (sum(d' <= sMax) == NUM_STAGES);
        % compute cost
        if validM
            cost = sum(D ~= baseAllocation, 'all') - sum(D(numInstances, : ), 'all');
            if cost < minCost
                minCost = cost;
                allocation = D;
            end
        end
    end
end

