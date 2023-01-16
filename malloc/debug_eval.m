clear;
clc;

NUM_STAGES = 20;
PARAM_GRANULARITY = 256;
PARAM_NUMAPPS = 128;
PARAM_EXPID = 0;

data_alloctime = readtable(sprintf( ...
    'stats_g%d_n%d/%d/alloctime.csv', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

data_utilization = readtable(sprintf( ...
    'stats_g%d_n%d/%d/utilization.csv', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

figure;
subplot(1, 2, 1);
plot(table2array(data_alloctime) * 1E3, '-x');
xlabel('App #');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;
subplot(1, 2, 2);
plot(table2array(data_utilization), '-x');
xlabel('App #');
ylabel('Utilization');
set(gca, 'FontSize', 16);
grid on;

set(gcf, 'Position', get(0, 'Screensize'));
saveas(gcf, sprintf( ...
    'debug_allocation_sequence_time_util_g%d_n%d_e%d.png', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

data_stageidx = readtable(sprintf( ...
    'stats_g%d_n%d/%d/stages.csv', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

key_stageidx = data_stageidx{ : , 1} * 10 + data_stageidx{ : , 2};

cost_current = zeros(1, NUM_STAGES);
cost_series = zeros(NUM_STAGES, PARAM_NUMAPPS);
for i = 1:size(data_stageidx, 1)
    idx_0 = data_stageidx{i, 1};
    idx_1 = data_stageidx{i, 2};
    cost_current(idx_0 + 1) = cost_current(idx_0 + 1) + 1;
    cost_current(idx_1 + 1) = cost_current(idx_1 + 1) + 1;
    for j = 1:NUM_STAGES
        cost_series(j, i) = cost_current(j);
        cost_series(j, i) = cost_current(j);
    end
end

used_stages = find(cost_current);

figure;

subplot(2, 2, 1);
for i = 1:length(used_stages)
    stage_idx = used_stages(i);
    plot(cost_series(stage_idx, : ), '-o');
    hold on;
end
xlabel('App #');
ylabel('Occupancy');
lgd = legend(cellstr(num2str(used_stages', 'N=%-d')));
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;

data_numblocks = readtable(sprintf( ...
    'stats_g%d_n%d/%d/numblocks.csv', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

subplot(2, 2, 2);
plot(data_numblocks{ : , 1}, '-o');
xlabel('App #');
ylabel('# Allocation Blocks');
set(gca, 'FontSize', 16);
grid on;

% xlim([65 75]);

subplot(2, 2, 3);
plot(key_stageidx, '-o');
xlabel('App #');
ylabel('Allocation Key');
set(gca, 'FontSize', 16);
grid on;

data_reallocations = readtable(sprintf( ...
    'stats_g%d_n%d/%d/costs.csv', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

subplot(2, 2, 4);
plot(data_reallocations{ : , 1}, '-x');
xlabel('App #');
ylabel('Reallocations');
set(gca, 'FontSize', 16);
grid on;

set(gcf, 'Position', get(0, 'Screensize'));
saveas(gcf, sprintf( ...
    'debug_allocation_sequence_g%d_n%d_e%d.png', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));

allocated_proportions = zeros(PARAM_NUMAPPS, PARAM_NUMAPPS);
fairness = zeros(1, PARAM_NUMAPPS);
for i = 1:PARAM_NUMAPPS
    data_allocmat = readtable(sprintf( ...
        'stats_g%d_n%d/%d/allocations/allocmatrix_%d.csv', ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        PARAM_EXPID, ...
        i - 1 ...
    ));
    allocmatrix = table2array(data_allocmat);
    [proportions, fairnessIndex] = getAllocatedProportions(allocmatrix);
    allocated_proportions(i,  1:length(proportions) ) = proportions;
    fairness(i) = fairnessIndex;
end

figure;

subplot(2, 1, 1);
boxplot(allocated_proportions');
xlabel('Allocation #');
ylabel('Proportion of Total Allocated');
set(gca, 'FontSize', 16);
grid on;

subplot(2, 1, 2);
plot(fairness, '-x');
xlabel('Allocation #');
ylabel('Fairness Index');
set(gca, 'FontSize', 16);
grid on;

set(gcf, 'Position', get(0, 'Screensize'));
saveas(gcf, sprintf( ...
    'debug_allocation_sequence_fairness_g%d_n%d_e%d.png', ...
    PARAM_GRANULARITY, ...
    PARAM_NUMAPPS, ...
    PARAM_EXPID ...
));