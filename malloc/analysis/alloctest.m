clear;
clc

MAX_ITER = 100;
NUM_STAGES = 20;
EARLY_TERMINATION = false;

constrLB = [3 7 8 9 10 11 12 13 14 15 16 17 18 19 20];
constrUB = [10 20 20 20 20 20 20 20 20 20 20 20 20 20 20];
constrMinSep = [3 4 0 0 0 0 0 0 0 0 0 0 0 0 0];
constrOpt = 3:15;

current = zeros(NUM_STAGES, 1);

current([2 5 7]) = 1;

alloc = getElasticHeuristicAllocation( ...
    constrLB, ...
    constrUB, ...
    constrMinSep, ...
    current, ...
    MAX_ITER, ...
    EARLY_TERMINATION, ...
    constrOpt ...
);

disp(mat2str(current'));
disp(mat2str(alloc'));

current = current + alloc;

disp(mat2str(current'));

utilization = sum(current > 0) / NUM_STAGES;
overlap = sum(current > 1) / sum(current > 0);

close(gcf);