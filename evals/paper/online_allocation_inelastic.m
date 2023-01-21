clear;
clc;

BASE_PATH = '../../malloc/evals/fit/wf/inelastic_cache';
OUTPUT_PATH = 'figures/allocator/inelastic_cache';

NUM_STAGES = 20;
PARAM_GRANULARITY = 256;
PARAM_NUMAPPS = 128;
PARAM_NUMEXP = 100;

% Bitmap format: allocation time, utilization
graphs = [1 1];

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
    ylim([0 max(cost_current)]);
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