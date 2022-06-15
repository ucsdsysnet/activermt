function [numValid, numTotal] = getNumValidAllocations(numInstances, midx, constrMaxStage, plen, maxMutations)
    NUM_STAGES = 20;
    
    c = ones(numInstances, 1);
    sMax = ones(NUM_STAGES, 1);
    
    numMutants = zeros(numInstances, 1);
    M = [];

    for j = 1:numInstances
        mutants = generateMutants(plen, midx, constrMaxStage);
        numMutants(j) = size(mutants, 2);
        M = [M; mutants'];
    end

    [cfgSize, mCfg] = enumerateDemands(numMutants, maxMutations);

    numValid = 0;
    for i = 1:cfgSize
        cfg = mCfg(i, :);
        D = zeros(numInstances, NUM_STAGES);
        preSum = 0;
        for j = 1:numInstances
            xidx = preSum + cfg(j);
            D(j, : ) = M(xidx, : );
            preSum = sum(numMutants(1:j));
        end
        d = c' * D;
        validM = (sum(d' <= sMax) == NUM_STAGES);
        if validM
            numValid = numValid + 1;
        end
    end
    
    numTotal = cfgSize;
end

