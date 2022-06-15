function [enumSize, demands] = enumerateDemands(numMutations, maxMutations)
    if maxMutations > 0
        enumSize = maxMutations * length(numMutations);
        demands = zeros(enumSize, length(numMutations));
        for i = 1:enumSize
            for j = 1:length(numMutations)
                demands(i, j) = randi(numMutations(j));
            end
        end
    else
        enumSize = 1;
        for i = 1:length(numMutations)
            enumSize = enumSize * numMutations(i);
        end
        demands = zeros(enumSize, length(numMutations));
        for i = 1:enumSize
            eidx = i - 1;
            j = 1;
            while eidx > 0 && j <= length(numMutations)
                demands(i, j) = mod(eidx, numMutations(j));
                eidx = floor(eidx / numMutations(j));
                j = j + 1;
            end
        end
    end
    demands = demands + 1;
end

