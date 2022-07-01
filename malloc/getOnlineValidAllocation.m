function [currentAlloc, success] = getOnlineValidAllocation(currentAllocSize, currentAlloc, constrLB, constrUB, constrSep, maxIter)
    
    NUM_STAGES = 20;
    C = ones(currentAllocSize + 1, 1);

    numMemaccesses = length(constrLB);
    A = zeros(numMemaccesses, numMemaccesses);
    A(1, 1) = 1;
    for i = 2:numMemaccesses
        A(i, i - 1) = -1;
        A(i, i) = 1;
    end

    success = false;
    for i = 1:maxIter
        isValid = false;
        memidx = [];
        while isValid == false
            memidx = round(rand(numMemaccesses, 1) * NUM_STAGES);
            if all(memidx' >= constrLB) && all(memidx' <= constrUB) && all((A * memidx) >= constrSep')
                isValid = true;
            end
        end
        currentAlloc(currentAllocSize + 1, memidx) = 1;
        x = currentAlloc(1:currentAllocSize+1, : );
        if all(sum(x, 1) <= C)
            success = true;
            break
        else
            currentAlloc(currentAllocSize + 1, : ) = 0;
        end
    end
end

