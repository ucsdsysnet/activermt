clear;
clc;

NUM_DATA_POINTS = 100;
DEFAULT_GRANULARITY = 256;
DEFAULT_NUMAPPS = 32;

param_granularity = [16 32 64 128 256];
param_numapps = [32 64 128 256 512];

% 1. keep granularity constant.

data_time_ms = zeros(length(param_numapps), NUM_DATA_POINTS);

for i = 1:length(param_numapps)
    datafile = sprintf( ...
        "evals/granularity/%d/allocation_cache_bf_relocations_%d.csv", ...
        param_numapps(i), ...
        DEFAULT_GRANULARITY ...
    );
    data = readtable(datafile);

    allocTime = data{ : , 4};
    numAllocations = data{ : , 5};

    assert(numAllocations(1) == param_numapps(i) && length(unique(numAllocations)) == 1);

    data_time_ms(i, : ) = allocTime(:) * 1E3;
end

figure;
boxplot(data_time_ms');
title(sprintf('Granularity = %d blocks', DEFAULT_GRANULARITY));
xticklabels(param_numapps);
xlabel('# Apps');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('allocation_time_avg_fixed_granularity_%d_blocks.png', DEFAULT_GRANULARITY));

% 2. keep number of apps constant.

data_time_ms_fixedapps = zeros(length(param_granularity), NUM_DATA_POINTS);

for i = 1:length(param_granularity)
    datafile = sprintf( ...
        "evals/granularity/%d/allocation_cache_bf_relocations_%d.csv", ...
        DEFAULT_NUMAPPS, ...
        param_granularity(i) ...
    );
    data = readtable(datafile);

    allocTime = data{ : , 4};
    numAllocations = data{ : , 5};

    assert(numAllocations(1) == DEFAULT_NUMAPPS && length(unique(numAllocations)) == 1);

    data_time_ms_fixedapps(i, : ) = allocTime(:) * 1E3;
end

figure;
boxplot(data_time_ms_fixedapps');
title(sprintf('# Apps = %d', DEFAULT_NUMAPPS));
xticklabels(param_granularity);
xlabel('Granularity (blocks)');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('allocation_time_avg_fixed_numapps_%d.png', DEFAULT_NUMAPPS));