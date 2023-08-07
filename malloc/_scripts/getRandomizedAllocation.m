function [allocation, attempts] = getRandomizedAllocation( ...
    constrLB, ...
    constrUB, ...
    constrMinSep, ...
    currentAlloc, ...
    maxIter ...
)
    
    NUM_STAGES = 20;

    numMemaccesses = length(constrUB);
    if isempty(constrLB)
        A = tril(ones(numMemaccesses));
        constrLB = (A * constrMinSep')';
    end
    A = zeros(numMemaccesses, numMemaccesses);
    A(1, 1) = 1;
    for i = 2:numMemaccesses
        A(i, i - 1) = -1;
        A(i, i) = 1;
    end

    attempts = zeros(maxIter, 1);
    for i = 1:maxIter
        isValid = false;
        memidx = [];
        allocation = zeros(NUM_STAGES, 1);
        validProgAttempts = 0;
        while isValid == false
            memidx = round(rand(numMemaccesses, 1) * NUM_STAGES);
            if all( ...
                    memidx' >= constrLB) && all(memidx' <= constrUB) ...
                    && ... 
                    all((A * memidx) >= constrMinSep' ...
                )
                isValid = true;
            end
            validProgAttempts = validProgAttempts + 1;
        end
        attempts(i) = validProgAttempts;
        allocation(memidx) = 1;
        if sum(currentAlloc(memidx)) == 0
            break
        end
    end
end

