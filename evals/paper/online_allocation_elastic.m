clear;
clc;

BASE_PATH = '../../malloc/evals/fit/wf/elastic_cache';
OUTPUT_PATH = 'figures/allocator/elastic_cache';

NUM_STAGES = 20;
PARAM_GRANULARITY = 256;
PARAM_NUMAPPS = 128;
PARAM_NUMEXP = 100;

% Bitmap format: allocation time, utilization, fairness, reallocations
graphs = [0 0 1 0];

% Allocation time.
if graphs(1) == 1

    allocation_time_ms = zeros(PARAM_NUMAPPS, PARAM_NUMEXP);
    
    for i = 1:PARAM_NUMEXP
    
        exp_id = i - 1;
        
        data_alloctime = readtable(sprintf( ...
            '%s/stats_g%d_n%d/%d/alloctime.csv', ...
            BASE_PATH, ...
            PARAM_GRANULARITY, ...
            PARAM_NUMAPPS, ...
            exp_id ...
        ));
    
        allocation_time_ms( : , i) = data_alloctime{ : , 1} * 1E3;
    
    end
    
    allocation_time_ms_median = median(allocation_time_ms, 2);

    figure;
    plot(allocation_time_ms_median, '-x');
    % ylim([5 10]);
    xlabel('App #');
    ylabel('Allocation Time (ms)');
    set(gca, 'FontSize', 16);
    grid on;
    saveas(gcf, sprintf('%s/online_allocation_time_d%d_n%d.png', OUTPUT_PATH, PARAM_GRANULARITY, PARAM_NUMAPPS));
end

% Allocator is deterministic, suffices to choose one instance.
exp_id = randsample(PARAM_NUMEXP, 1) - 1;

% Utilization.
if graphs(2) == 1

    data_utilization = readtable(sprintf( ...
        '%s/stats_g%d_n%d/%d/utilization.csv', ...
        BASE_PATH, ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        exp_id ...
    ));

    data_stageidx = readtable(sprintf( ...
        '%s/stats_g%d_n%d/%d/stages.csv', ...
        BASE_PATH, ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        exp_id ...
    ));

    cost_current = zeros(1, NUM_STAGES);
    cost_series = zeros(NUM_STAGES, PARAM_NUMAPPS);
    for i = 1:size(data_stageidx, 1)
        for j = 1:size(data_stageidx, 2)
            idx = data_stageidx{i, j};
            if idx < 0
                continue;
            end
            cost_current(idx + 1) = cost_current(idx + 1) + 1;
        end
        for j = 1:NUM_STAGES
            cost_series(j, i) = cost_current(j);
        end
    end
    
    used_stages = find(cost_current);

    figure;
    yyaxis left;
    for i = 1:length(used_stages)
        stage_idx = used_stages(i);
        plot(cost_series(stage_idx, : ));
        hold on;
    end
    ylabel('Occupancy');
    yyaxis right;
    plot(data_utilization{ : , 1}, '-x');
    ylabel('Overall Utilization');
    lgd = legend(cellstr(num2str(used_stages', 'N=%-d')));
    lgd.Location = 'southeast';
    set(gca, 'FontSize', 16);
    xlabel('App #');
    grid on;
    saveas(gcf, sprintf('%s/online_utilization_d%d_n%d.png', OUTPUT_PATH, PARAM_GRANULARITY, PARAM_NUMAPPS));
end

% Fairness.
if graphs(3) == 1

    allocmatfiles = dir(sprintf( ...
        '%s/stats_g%d_n%d/%d/allocations/allocmatrix*', ...
        BASE_PATH, ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        exp_id ...
    ));

    num_apps_actual = size(allocmatfiles, 1);

    allocated_proportions = zeros(num_apps_actual, num_apps_actual);
    fairness = zeros(1, num_apps_actual);
    for i = 1:num_apps_actual
        data_allocmat = readtable(sprintf( ...
            '%s/stats_g%d_n%d/%d/allocations/allocmatrix_%d.csv', ...
            BASE_PATH, ...
            PARAM_GRANULARITY, ...
            PARAM_NUMAPPS, ...
            exp_id, ...
            i - 1 ...
        ));
        allocmatrix = table2array(data_allocmat);
        [proportions, fairnessIndex] = getAllocatedProportions(allocmatrix);
        allocated_proportions(i,  1:length(proportions) ) = proportions;
        fairness(i) = fairnessIndex;
    end

    allocated_proportions(allocated_proportions == 0) = NaN;
    allocated_proportions = allocated_proportions';

    prop_lb = min(allocated_proportions, [], 1);
    prop_ub = max(allocated_proportions, [], 1);
    prop_avg = nanmean(allocated_proportions, 1);

    err_neg = prop_avg - prop_lb;
    err_pos = prop_ub - prop_avg;

    figure;
    yyaxis left;
%     boxplot(allocated_proportions');
    errorbar(1:PARAM_NUMAPPS, prop_avg, err_neg, err_pos);
    hold on;
    set(gca, 'YScale', 'log');
    ylabel('Allocated Memory Blocks');
    yyaxis right;
    plot(fairness, '-o');
    ylabel('Fairness Measure');
    xlabel('Allocation #');
    set(gca, 'FontSize', 16);
    grid on;
%     set(gcf, 'Position', get(0, 'Screensize'));
    saveas(gcf, sprintf('%s/online_fairness_d%d_n%d.png', OUTPUT_PATH, PARAM_GRANULARITY, PARAM_NUMAPPS));
end

% Reallocations.
if graphs(4) == 1

    data_reallocations = readtable(sprintf( ...
        '%s/stats_g%d_n%d/%d/costs.csv', ...
        BASE_PATH, ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        exp_id ...
    ));

    figure;
    plot(data_reallocations{ : , 1}, '-x');
    xlabel('App #');
    ylabel('Reallocations');
    set(gca, 'FontSize', 16);
    grid on;
    saveas(gcf, sprintf('%s/online_reallocations_d%d_n%d.png', OUTPUT_PATH, PARAM_GRANULARITY, PARAM_NUMAPPS));
end