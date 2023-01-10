clear;
clc;

NUM_STAGES = 20;
PARAM_GRANULARITY = 256;
PARAM_NUMAPPS = 128;
PARAM_EXPID = 0;

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