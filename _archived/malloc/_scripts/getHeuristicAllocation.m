function [allocation] = getHeuristicAllocation(constrUB, constrMinSep, currentAlloc, maxIter)
    NUM_STAGES = 20;
    numAccesses = length(constrUB);    
    A = tril(ones(numAccesses));
    constrLB = (A * constrMinSep')';
    A = zeros(numAccesses);
    A(1, 1) = 1;
    for r = 2:numAccesses
        A(r, r - 1) = -1;
        A(r, r) = 1;
    end
    A = -A;
    constrMinSep = -constrMinSep;
    f = @(x) sum(currentAlloc(x));
    options = optimoptions('surrogateopt', 'PlotFcn', 'surrogateoptplot', 'MaxFunctionEvaluations', maxIter, 'ObjectiveLimit', 1);
    x = surrogateopt(f, constrLB, constrUB, 1:numAccesses, A, constrMinSep, [], [], options);
    allocation = zeros(NUM_STAGES, 1);
    allocation(x) = 1;
end