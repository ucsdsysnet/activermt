%{
Online allocation using heuristic-based solver.
Metrics: fairness, utilization, execution time.
%}

clear;
clc

SHARED_EN = 0;
ELASTIC_EN = 1;

ALLOC_TYPE_RANDOMIZED = 1;
ALLOC_TYPE_HEURISTIC = 2;

EARLY_TERMINATION = false;
MAX_ITER = 100;
NUM_STAGES = 20;
NUM_INSTANCES = NUM_STAGES;
NUM_REPEATS = 1000;
ARRIVAL_PROB = 0.5;

cacheConstrLB = [3 7 8 9 10 11 12 13 14 15 16 17 18 19 20];
cacheConstrUB = [10 20 20 20 20 20 20 20 20 20 20 20 20 20 20];
cacheConstrMinSep = [3 4 0 0 0 0 0 0 0 0 0 0 0 0 0];
cacheConstrOpt = 3:15;

lbConstrLB = [2 5 7];
lbConstrUB = [10 10 10];
lbConstrMinSep = [2 3 2];
lbConstrOpt = [];

allocationType = ALLOC_TYPE_HEURISTIC;

fskew = zeros(NUM_REPEATS, 2);
numAllocated = zeros(NUM_REPEATS, 1);
utilization = zeros(NUM_REPEATS, 1);
overlap = zeros(NUM_REPEATS, 1);
executionTime = zeros(NUM_REPEATS, NUM_STAGES);
sequence = zeros(NUM_REPEATS, NUM_STAGES);

parfor k = 1:NUM_REPEATS
    fprintf('[Iteration %d]\n', k);
    current = zeros(NUM_STAGES, 1);
    shares = zeros(NUM_STAGES, 1);
    appcounts = [0 0];
    for i = 1:NUM_INSTANCES
        fprintf('Attempting allocation for instance %d\n', i);
        if rand() <= ARRIVAL_PROB
            constrLB = cacheConstrLB;
            constrUB = cacheConstrUB;
            constrMinSep = cacheConstrMinSep;
            constrOpt = cacheConstrOpt;
            fidx = 1;
        else
            constrLB = lbConstrLB;
            constrUB = lbConstrUB;
            constrMinSep = lbConstrMinSep;
            constrOpt = lbConstrOpt;
            fidx = 2;
        end
        tStart = tic;
        if allocationType == ALLOC_TYPE_HEURISTIC
            if ELASTIC_EN == 0
                alloc = getHeuristicAllocation( ...
                    constrUB, ...
                    constrMinSep, ...
                    current, ...
                    MAX_ITER ...
                );
            else
                alloc = getElasticHeuristicAllocation( ...
                    constrLB, ...
                    constrUB, ...
                    constrMinSep, ...
                    current, ...
                    MAX_ITER, ...
                    EARLY_TERMINATION, ...
                    constrOpt ...
                );
            end
        else
            alloc = getRandomizedAllocation( ...
                [], ...
                constrUB, ...
                constrMinSep, ...
                current, ...
                MAX_ITER ...
            );
        end
        elapsed = toc(tStart);
        if SHARED_EN == 0 && sum(bitand(current, alloc), "all") ~= 0
            break
        end
        shares = shares + alloc * fidx;
        appcounts(fidx) = appcounts(fidx) + 1;
        sequence(k, i) = fidx;
        executionTime(k, i) = elapsed;
        if SHARED_EN == 0
            current = bitor(current, alloc);
        else
            current = current + alloc;
        end
        numAllocated(k) = numAllocated(k) + 1;
    end
    disp(mat2str(shares'));
    fskew(k, : ) = appcounts;
    memIdx = find(current);
    overlap(k) = (sum(current(memIdx)) - length(memIdx)) / sum(current(memIdx));
    utilization(k) = sum(current > 0) / NUM_STAGES;
end

close(gcf);

if ELASTIC_EN == 1
    param_etype = 'elastic';
else
    param_etype = 'inelastic';
end

if SHARED_EN == 0
    param_atype = 'exclusive';
else
    param_atype = 'shared';
end

if allocationType == ALLOC_TYPE_RANDOMIZED
    param_algo = 'randomized';
else
    param_algo = 'heuristic';
end

paramstr = sprintf( ...
    '%s_%s_%s_i%d_r%d_p%f', ...
    param_etype, ...
    param_atype, ...
    param_algo, ...
    MAX_ITER, ...
    NUM_REPEATS, ...
    ARRIVAL_PROB ...
);

% function distribution vs sequence length.
figure
maxdiameter = 10000;
fratio = fskew ./ sum(fskew, 2);
ftotal = sum(fskew, 2);
for k = 1:2
    fcounts = zeros(NUM_STAGES + 1, NUM_STAGES + 1);
    for i = 1:NUM_REPEATS
        x = fskew(i, k) + 1;
        y = ftotal(i) + 1;
        fcounts(x, y) = fcounts(x, y) + 1;
    end
    [fx, fy] = find(fcounts);
    D = zeros(length(fx), 1);
    for i = 1:length(fx)
        D(i) = fcounts(fx(i), fy(i)) * maxdiameter / NUM_REPEATS;
    end
    Y = (fx - 1) ./ (fy - 1);
    scatter(fy, Y, D, 'o');
    hold on
end
title('Effect of function arrival on occupancy');
ylabel('Proportion of allocations');
xlabel('Total allocations');
legend('Cache', 'LB');
set(gca, 'FontSize', 16);
grid on
saveas(gcf, sprintf('proportions_%s.fig', paramstr));
saveas(gcf, sprintf('proportions_%s.png', paramstr));
save(sprintf('proportions_%s.mat', paramstr), "fskew");

% execution time.
for i = 1:NUM_STAGES
    s = sequence( : , i);
    if all(s == 0)
        break
    end
end
figure
executionTime(executionTime == 0) = NaN;
boxplot(executionTime( : , 1:i-1));
title('Effect of arrival order on allocation time');
xlabel('Seq Idx');
ylabel('Execution time (seconds)');
set(gca, 'FontSize', 16);
grid on
saveas(gcf, sprintf('execution_time_%s.fig', paramstr));
saveas(gcf, sprintf('execution_time_%s.png', paramstr));
save(sprintf('execution_time_%s.mat', paramstr), "executionTime");

% memory utilization
figure
boxplot(utilization);
title('Memory utilization');
ylim([0 1]);
ylabel('Utilization');
set(gca, 'FontSize', 16);
grid on
saveas(gcf, sprintf('utilization_%s.fig', paramstr));
saveas(gcf, sprintf('utilization_%s.png', paramstr));
save(sprintf('utilization_%s.mat', paramstr), "utilization");

% memory stage overlap
figure
boxplot(overlap);
title('Overlapping stages');
ylim([0 1]);
ylabel('Shared memory region');
set(gca, 'FontSize', 16);
grid on
saveas(gcf, sprintf('overlap_%s.fig', paramstr));
saveas(gcf, sprintf('overlap_%s.png', paramstr));
save(sprintf('overlap_%s.mat', paramstr), "overlap");