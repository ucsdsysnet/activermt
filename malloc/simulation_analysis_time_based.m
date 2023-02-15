clear;
clc;

BASE_DIR = '.';
NUM_STAGES = 20;
PARAM_GRANULARITY = 368;
PARAM_DURATION = 1000;
PARAM_FIT = 'wf';
PARAM_NUMREPS = 10;
PARAM_WL = 'random';
PARAM_ARRIVAL_RATE = 2;

EWMA_ALPHA = 0.6;
EWMA_FILTER = ones(1, 10);
for i = 2:10
    EWMA_FILTER(i) = EWMA_FILTER(i - 1) * 2;
end
EWMA_FILTER = EWMA_FILTER / sum(EWMA_FILTER);

params_constraints = {'lc', 'mc'};

param_markers = {'--square', '-x'};
param_colors = {'r', 'b', 'g', 'm'};

labels_constraints = {'least-constr', 'most-constr'};

% utilization, occupancy, reallocations, failures, fairness.
graphs = [0 0 1 0 0];

if graphs(1) == 1
    figure;
    for i = 1:length(params_constraints)
        wl = PARAM_WL;
        constr = params_constraints{i};
    
        utilization = zeros(PARAM_DURATION, PARAM_NUMREPS);
    
        for j = 1:PARAM_NUMREPS
            exp_id = j - 1;
            data_utilization = readtable(sprintf( ...
                '%s/timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/utilization.csv', ...
                BASE_DIR, ...
                PARAM_GRANULARITY, ...
                PARAM_DURATION, ...
                wl, ...
                PARAM_FIT, ...
                constr, ...
                PARAM_ARRIVAL_RATE, ...
                exp_id ...
            ));
            utilization( : , j) = data_utilization{ : , 1};
        end
    
        util_avg = mean(utilization, 2);
        util_lb = min(utilization, [], 2);
        util_ub = max(utilization, [], 2);
        err_neg = util_avg - util_lb;
        err_pos = util_ub - util_avg;

        X1 = [1:PARAM_DURATION,fliplr(1:PARAM_DURATION)];
        Y1 = [util_lb',fliplr(util_ub')];

        p = fill(X1, Y1, param_colors{i}, 'EdgeColor', 'none');
        p.FaceAlpha = 0.4;
    
%         errorbar(1:PARAM_DURATION, util_avg, err_neg, err_pos);
        hold on;
        plot(1:PARAM_DURATION, util_avg, '-', 'Color', param_colors{i}, 'LineWidth', 1.5);
        hold on;
    end
    
    ylim([0 1]);
    ylabel('Utilization');
    xlabel('Time Interval');
    lgd = legend({'least-constr (range)', 'least-constr (avg)', 'most-constr (range)', 'most-constr (avg)'});
    lgd.Location = 'southeast';
    lgd.FontSize = 12;
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('utilization_sim_%s_%d_ticks.png', PARAM_WL, PARAM_DURATION));
end

if graphs(2) == 1
    figure;
    param_markers = {'--', '-'};
    for i = 1:length(params_constraints)
        wl = PARAM_WL;
        constr = params_constraints{i};
    
        occupancy = zeros(PARAM_DURATION, PARAM_NUMREPS);
        failures = zeros(PARAM_DURATION, PARAM_NUMREPS);
    
        for j = 1:PARAM_NUMREPS
            exp_id = j - 1;
            data_occupancy = readtable(sprintf( ...
                '%s/timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/occupancy.csv', ...
                BASE_DIR, ...
                PARAM_GRANULARITY, ...
                PARAM_DURATION, ...
                wl, ...
                PARAM_FIT, ...
                constr, ...
                PARAM_ARRIVAL_RATE, ...
                exp_id ...
            ));
            occupancy( : , j) = data_occupancy{ : , 1};
            data_failures = readtable(sprintf( ...
                '%s/timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/failures.csv', ...
                BASE_DIR, ...
                PARAM_GRANULARITY, ...
                PARAM_DURATION, ...
                wl, ...
                PARAM_FIT, ...
                constr, ...
                PARAM_ARRIVAL_RATE, ...
                exp_id ...
            ));
            Xf = data_failures{ : , 1};
            failures(1, j) = Xf(1);
            for k = 2:PARAM_DURATION
                failures(k, j) = failures(k - 1, j) + Xf(k);
            end
        end
    
        occ_avg = mean(occupancy, 2);
        occ_lb = min(occupancy, [], 2);
        occ_ub = max(occupancy, [], 2);
        err_neg = occ_avg - occ_lb;
        err_pos = occ_ub - occ_avg;

        X1 = [1:PARAM_DURATION,fliplr(1:PARAM_DURATION)];
        Y1 = [occ_lb',fliplr(occ_ub')];

%         yyaxis left;
        p = fill(X1, Y1, param_colors{i}, 'EdgeColor', 'none');
        p.FaceAlpha = 0.4;
    
%         errorbar(1:PARAM_DURATION, occ_avg, err_neg, err_pos);
        hold on;
        plot(1:PARAM_DURATION, occ_avg, '-', 'Color', param_colors{i}, 'LineWidth', 1.5);
        hold on;
        
%         yyaxis right;
%         Yf = mean(failures, 2);
%         plot(Yf, param_markers{i}, 'LineWidth', 2, 'Color', 'k');
%         hold on;
    end
    
%     yyaxis left;
    ylabel('Concurrency (# active apps)');
%     yyaxis right;
%     ylabel('Cumulative failed allocations');
    xlabel('Time Interval');
%     lgd = legend({'least-constr (range)', 'least-constr (avg)', 'most-constr (range)', 'most-constr (avg)', 'least-constr (avg)', 'most-constr (avg)'});
    lgd = legend({'least-constr (range)', 'least-constr (avg)', 'most-constr (range)', 'most-constr (avg)'});
%     lgd.Location = 'southeast';
    lgd.Location = 'northwest';
    lgd.FontSize = 12;
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('occupancy_sim_%s_%d_ticks.png', PARAM_WL, PARAM_DURATION));
end

if graphs(3) == 1
    window_size = PARAM_DURATION / 10;
    mwa_filter = ones(1, window_size) / window_size;
    figure;
    for i = 1:length(params_constraints)
        wl = PARAM_WL;
        constr = params_constraints{i};

        reallocations_pct_total = zeros(PARAM_DURATION, PARAM_NUMREPS);
        reallocations_pct_elastic = zeros(PARAM_DURATION, PARAM_NUMREPS);
    
        for j = 1:PARAM_NUMREPS
            exp_id = j - 1;
            data_reallocations = readtable(sprintf( ...
                '%s/timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/reallocations.csv', ...
                BASE_DIR, ...
                PARAM_GRANULARITY, ...
                PARAM_DURATION, ...
                wl, ...
                PARAM_FIT, ...
                constr, ...
                PARAM_ARRIVAL_RATE, ...
                exp_id ...
            ));
            I = 1:size(data_reallocations, 1);
            reallocations_pct_total( I , j) = data_reallocations{ : , 1} ./ data_reallocations{ : , 2};
            reallocations_pct_elastic( I , j) = data_reallocations{ : , 1} ./ data_reallocations{ : , 3};
        end

        reallocations_pct_elastic(isnan(reallocations_pct_elastic)) = 0;
%         reallocations_pct_total(isnan(reallocations_pct_total)) = 0;
    
%         cost_avg_total = mean(reallocations_pct_total, 2);
%         cost_lb_total = min(reallocations_pct_total, [], 2);
%         cost_ub_total = max(reallocations_pct_total, [], 2);

        cost_avg_elastic = mean(reallocations_pct_elastic, 2);
        cost_lb_elastic = min(reallocations_pct_elastic, [], 2);
        cost_ub_elastic = max(reallocations_pct_elastic, [], 2);

%         X1 = [1:PARAM_DURATION,fliplr(1:PARAM_DURATION)];
%         Y1 = [cost_lb_total',fliplr(cost_ub_total')];

        X2 = [1:PARAM_DURATION,fliplr(1:PARAM_DURATION)];
        Y2 = [cost_lb_elastic',fliplr(cost_ub_elastic')];

%         c = 2 * (i - 1);

%         p = fill(X1, Y1, param_colors{c + 1}, 'EdgeColor', 'none');
%         p.FaceAlpha = 0.4;
%         hold on;
%         plot(1:PARAM_DURATION, cost_avg_total * 100, '-', 'Color', param_colors{c + 1}, 'LineWidth', 1.5);
%         hold on;

        p = fill(X2, Y2 * 100, param_colors{i}, 'EdgeColor', 'none');
        p.FaceAlpha = 0.4;
        hold on;
%         plot(1:PARAM_DURATION, cost_avg_elastic * 100, '-', 'Color', param_colors{i}, 'LineWidth', 1.5);
%         hold on;

%         emwa_total = conv(cost_avg_total, EWMA_FILTER) * 100;
%         emwa_elastic = conv(cost_avg_elastic, EWMA_FILTER) * 100;

%         emwa_total = ewma(cost_avg_total, EWMA_ALPHA) * 100;
        emwa_elastic = ewma(cost_avg_elastic, EWMA_ALPHA) * 100;

%         plot(1:PARAM_DURATION, emwa_total(1:PARAM_DURATION), '-', 'Color', param_colors{c + 1}, 'LineWidth', 1.5);
%         hold on;
        plot(1:PARAM_DURATION, emwa_elastic(1:PARAM_DURATION), '-', 'Color', param_colors{i}, 'LineWidth', 1.5);
        hold on;

%         mwa = conv(cost_avg, mwa_filter);
%         mwa_elastic = conv(elastic_avg, mwa_filter);
    
%         cdfplot(reallocations_pct_total(:) * 100);
%         hold on;
%         cdfplot(reallocations_pct_elastic(:) * 100);
%         hold on;
    end
    
%     xlabel('Reallocations (%)');
    ylabel('Reallocations (%)');
    xlabel('Time Interval');
    xlim([1, PARAM_DURATION]);
%     lgd = legend({'least-constr (all)', 'least-constr (elastic)', 'most-constr (all)', 'most-constr (elastic)'});
    lgd = legend({'least-constr (range)', 'least-constr (avg)', 'most-constr (range)', 'most-constr (avg)'});
%     lgd = legend(labels_constraints);
%     lgd.Location = 'southeast';
    lgd.Location = 'northeast';
    lgd.FontSize = 12;
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('reallocations_sim_%s_%d_ticks.png', PARAM_WL, PARAM_DURATION));
end

if graphs(4) == 1
    figure;
    for i = 1:length(params_constraints)
        wl = PARAM_WL;
        constr = params_constraints{i};
    
        failures = zeros(PARAM_DURATION, PARAM_NUMREPS);
    
        for j = 1:PARAM_NUMREPS
            exp_id = j - 1;
            data_failures = readtable(sprintf( ...
                '%s/timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/failures.csv', ...
                BASE_DIR, ...
                PARAM_GRANULARITY, ...
                PARAM_DURATION, ...
                wl, ...
                PARAM_FIT, ...
                constr, ...
                PARAM_ARRIVAL_RATE, ...
                exp_id ...
            ));
            X1 = data_failures{ : , 1};
            failures(1, j) = X1(1);
            for k = 2:PARAM_DURATION
                failures(k, j) = failures(k - 1, j) + X1(k);
            end
%             failures( : , j) = data_failures{ : , 1};
            hold on;
        end
    
        Y1 = mean(failures, 2);
        plot(Y1);
    
        hold on;
    end
    
    xlabel('Time Interval');
    ylabel('SUM(failures)');
    lgd = legend(labels_constraints);
    lgd.Location = 'northwest';
    lgd.FontSize = 12;
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('failures_sim_%s_%d_ticks.png', PARAM_WL, PARAM_DURATION));
end

if graphs(5) == 1 && strcmp(PARAM_WL, 'inelastic') == 0
    figure;
    for i = 1:length(params_constraints)
        wl = PARAM_WL;
        constr = params_constraints{i};
        fairness = zeros(PARAM_DURATION, PARAM_NUMREPS);
        for j = 1:PARAM_NUMREPS
            exp_id = j - 1;
            data_fairness = readtable(sprintf( ...
                '%s/timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/fairness.csv', ...
                BASE_DIR, ...
                PARAM_GRANULARITY, ...
                PARAM_DURATION, ...
                wl, ...
                PARAM_FIT, ...
                constr, ...
                PARAM_ARRIVAL_RATE, ...
                exp_id ...
            ), 'NumHeaderLines', 0);
            n = size(data_fairness, 1);
            fairness( 1:n , j) = data_fairness{ : , 1};
        end
        
        fairness(fairness == 0) = NaN;
        
        fairness_avg = mean(fairness, 2);
        fairness_lb = min(fairness, [], 2);
        fairness_ub = max(fairness, [], 2);
        err_neg = fairness_avg - fairness_lb;
        err_pos = fairness_ub - fairness_avg;

        X1 = [1:PARAM_DURATION,fliplr(1:PARAM_DURATION)];
        Y1 = [fairness_lb',fliplr(fairness_ub')];

        p = fill(X1, Y1, param_colors{i}, 'EdgeColor', 'none');
        p.FaceAlpha = 0.4;
%         p = cdfplot(fairness(:));
%         set(p, 'LineWidth', 2);
        hold on;
        plot(1:PARAM_DURATION, fairness_avg, '-', 'Color', param_colors{i}, 'LineWidth', 1.5);
        hold on;
    end
    
    xlabel('Time Interval');
    ylabel('Fairness Index');
%     lgd = legend(labels_constraints);
    lgd = legend({'least-constr (range)', 'least-constr (avg)', 'most-constr (range)', 'most-constr (avg)'});
    lgd.Location = 'southeast';
    lgd.FontSize = 12;
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('fairness_sim_%s_%d_ticks.png', PARAM_WL, PARAM_DURATION));
end