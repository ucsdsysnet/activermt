clear;
clc

INST_LB = 1;
INST_CACHE = 2;

NUM_STAGES = 20;
MAX_INSTANCES = NUM_STAGES;
MAX_ITER = 1000;
NUM_REPEATS = 100;

memConstrLB = [0 0];
memConstrUB = [10 20];
memConstrMinSep = [3 4];

lbConstrLB = [0 0 0];
lbConstrUB = [10 10 10];
lbConstrMinSep = [2 3 2];

executionTime = zeros(MAX_INSTANCES, NUM_REPEATS);
instanceId = zeros(MAX_INSTANCES, NUM_REPEATS);
successRate = zeros(MAX_INSTANCES, 1);
instanceCount = zeros(NUM_REPEATS, 1);

for r = 1:NUM_REPEATS
    allocations = zeros(MAX_INSTANCES, NUM_STAGES);
    numInstances = 0;
    while numInstances < MAX_INSTANCES
        numInstances = numInstances + 1;
        if rand() < 0.5
            constrLB = memConstrLB;
            constrUB = memConstrUB;
            constrMinSep = memConstrMinSep;
            instanceId(numInstances, r) = INST_CACHE;
        else
            constrLB = lbConstrLB;
            constrUB = lbConstrUB;
            constrMinSep = lbConstrMinSep;
            instanceId(numInstances, r) = INST_LB;
        end
        tStart = tic;
        [allocations, success] = getOnlineValidAllocation(numInstances - 1, allocations, constrLB, constrUB, constrMinSep, MAX_ITER);
        if success == false
            break
        end
        successRate(numInstances) = successRate(numInstances) + 1;
        executionTime(numInstances, r) = toc(tStart);
    end
    instanceCount(r) = numInstances;
end

maxAllocatedInstances = max(instanceCount);

meanExecTimes = zeros(maxAllocatedInstances, 1);
for i = 1:maxAllocatedInstances
    execIdx = executionTime(i, : ) > 0;
    meanExecTimes(i) = mean(executionTime(i, execIdx), 2);
end

successRate = successRate / NUM_REPEATS;

figure
bar(1:maxAllocatedInstances, successRate(1:maxAllocatedInstances));
xlabel('# instances');
ylabel('Success Rate');
grid on
set(gca, 'FontSize', 16);
xticks(1:maxAllocatedInstances);

figure

subplot(2,1,1);
plot(1:maxAllocatedInstances, meanExecTimes, '-x');
title(sprintf('Online (random) allocation'));
xlabel('# instances');
ylabel('Execution time (seconds)');
grid on
set(gca, 'FontSize', 16);
xticks(1:maxAllocatedInstances);

subplot(2,1,2);
for i = 1:NUM_REPEATS
    plot(1:maxAllocatedInstances, executionTime(1:maxAllocatedInstances, i ), '-o');
    hold on
end
title(sprintf('[max trials = %d]', MAX_ITER));
xlabel('# instances');
ylabel('Execution time (seconds)');
sequence = num2str(instanceId(1:maxAllocatedInstances, 1), '-%d');
legend(cellstr(num2str((1:NUM_REPEATS)', 'Iter=%-d')));
set(gca, 'FontSize', 16);
xticks(1:maxAllocatedInstances);
grid on