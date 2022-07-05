%{
Online (mutation-based) memory allocation using randomized approach.
Memory access pattern: cache/lb.
%}

clear;
clc

INST_LB = 1;
INST_CACHE = 2;
ARRIVAL_PROB = 0.5;

NUM_STAGES = 20;
MAX_INSTANCES = NUM_STAGES;
MAX_ITER = 10000;
NUM_REPEATS = 1000;

cacheConstrLB = [0 0];
cacheConstrUB = [10 20];
cacheConstrMinSep = [3 4];

lbConstrLB = [0 0 0];
lbConstrUB = [10 10 10];
lbConstrMinSep = [2 3 2];

sequence = zeros(NUM_REPEATS, MAX_INSTANCES);
executionTime = zeros(NUM_REPEATS, MAX_INSTANCES);
timeVariance = zeros(NUM_REPEATS, 1);
instanceCount = zeros(NUM_REPEATS, 1);
utilization = zeros(NUM_REPEATS, 1);

for r = 1:NUM_REPEATS
    allocations = zeros(MAX_INSTANCES, NUM_STAGES);
    numInstances = 0;
    while numInstances < MAX_INSTANCES
        numInstances = numInstances + 1;
        if rand() < ARRIVAL_PROB
            constrLB = cacheConstrLB;
            constrUB = cacheConstrUB;
            constrMinSep = cacheConstrMinSep;
            sequence(r, numInstances) = INST_CACHE;
        else
            constrLB = lbConstrLB;
            constrUB = lbConstrUB;
            constrMinSep = lbConstrMinSep;
            sequence(r, numInstances) = INST_LB;
        end
        tStart = tic;
        [allocations, success] = getOnlineValidAllocation(numInstances - 1, allocations, constrLB, constrUB, constrMinSep, MAX_ITER);
        if success == false
            break
        end
        executionTime(r, numInstances) = toc(tStart);
    end
    timeVariance(r) = var(executionTime(r, 1:numInstances));
    utilization(r) = sum(allocations, 'all') / NUM_STAGES;
    instanceCount(r) = numInstances;
end

figure
cdfplot(timeVariance);
title(sprintf('Execution time variance across runs'));
xlabel('Execution time (seconds)');
grid on
set(gca, 'FontSize', 16);

figure
histogram(utilization);
title('Memory utilization across runs');
xlabel('Memory utilization');
grid on
set(gca, 'FontSize', 16);

figure
histogram(instanceCount);
title('Successfully allocated instances across runs');
xlabel('# instances');
grid on
set(gca, 'FontSize', 16);

% legend(cellstr(num2str((1:NUM_REPEATS)', 'Iter=%-d')));