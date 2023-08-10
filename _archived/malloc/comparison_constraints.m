clear;
clc;

NUM_STAGES = 20;
PARAM_GRANULARITY = 368;
PARAM_NUMAPPS = 128;
PARAM_EXPID = 3;
PARAM_WORKLOAD = 'freqitem';
PARAM_FIT = 'wf';
PARAM_NUMREPS = 10;

colors_light = {[1.0000    0.4118    0.1608], [0.0745    0.6235    1.0000], [0.3922    0.8314    0.0745], [1.0000    0.0745    0.6510]};
colors_dark = {[0.8510    0.3255    0.0980], [0    0.4471    0.7412], [0.4667    0.6745    0.1882], [0.6353    0.0784    0.1843]};

compare_params_constraints = {'lc', 'mc'};
compare_params_workloads = {'cache', 'freqitem', 'cheetahlb', 'random'};

labels_constraints = {'least-constr', 'most-constr'};
labels_workloads = {'cache', 'hh', 'lb', 'random'};

param_markers = {'--square', '-x'};
param_colors = {'r', 'b', 'g', 'k'};

% reallocations, utilization, time, utilization (random)
graphs = [0 0 1 0];

if graphs(1) == 1
    figure;
    markers_reallocations = {'--', '-', ':', '-'};
    colors_reallocations = {'r', 'k'};
    workloads_reallocations = {'cache', 'random'};
    L = cell(1, length(compare_params_constraints) * length(workloads_reallocations));
    for k = 1:length(workloads_reallocations)
        for i = 1:length(compare_params_constraints)
            data = zeros(PARAM_NUMAPPS, PARAM_NUMREPS);
            for j = 1:PARAM_NUMREPS
                data_enumsizes = readtable(sprintf( ...
                    'stats_g%d_n%d_%s_%s_%s/%d/enumsizes.csv', ...
                    PARAM_GRANULARITY, ...
                    PARAM_NUMAPPS, ...
                    workloads_reallocations{k}, ...
                    PARAM_FIT, ...
                    compare_params_constraints{i}, ...
                    j - 1 ...
                ));
                I = data_enumsizes{ : , 1} == 0;
        
                data_costs = readtable(sprintf( ...
                    'stats_g%d_n%d_%s_%s_%s/%d/costs.csv', ...
                    PARAM_GRANULARITY, ...
                    PARAM_NUMAPPS, ...
                    'random', ...
                    PARAM_FIT, ...
                    compare_params_constraints{i}, ...
                    j - 1 ...
                ));
                
                reallocations_pct = data_costs{ : , 1} ./ [1:PARAM_NUMAPPS]';
                reallocations_pct(I) = NaN;
                
                data( : , j) = reallocations_pct * 100;
            end
            data = mean(data, 2);
            h = cdfplot(data);
            set(h, 'LineStyle', markers_reallocations{(k-1) * 2 + i}, 'Color', colors_reallocations{k});
            hold on;
            L((k-1)*2+i) = cellstr(sprintf('%s (%s)', workloads_reallocations{k}, labels_constraints{i}));
        end
    end
    
    xlabel('% reallocated');
    lgd = legend(L);
    lgd.Location = 'southeast';
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('comparison_reallocations_random_cache.png'));
end

if graphs(2) == 1
    seqlen = [128 128 1024 128];
    workloads_utilization = {'cache', 'freqitem', 'cheetahlb'};
    utildata = zeros(length(workloads_utilization), length(compare_params_constraints));
    numapps = zeros(length(workloads_utilization), length(compare_params_constraints));
    for k = 1:length(workloads_utilization)
        for i = 1:length(compare_params_constraints)
            data = zeros(seqlen(k), PARAM_NUMREPS);
            for j = 1:PARAM_NUMREPS
                data_utilization = readtable(sprintf( ...
                    'stats_g%d_n%d_%s_%s_%s/%d/utilization.csv', ...
                    PARAM_GRANULARITY, ...
                    seqlen(k), ...
                    compare_params_workloads{k}, ...
                    PARAM_FIT, ...
                    compare_params_constraints{i}, ...
                    j - 1 ...
                ));
                utilization = data_utilization{ : , 1};
                utilization(utilization == 0) = NaN;
                data( : , j) = utilization;
                utilmax = max(utilization, [], 'all');
                if utilmax > utildata(k, i)
                    utildata(k, i) = utilmax;
                    numapps(k, i) = find(utilization == utildata(k, i), 1);
                end
            end
        end
    end
    
    figure;
    yyaxis left;
    b = bar(utildata);
    for i = 1:length(compare_params_constraints)
        b(i).FaceColor = colors_light{i};
    end
    ylabel('Utilization');
    yyaxis right;
    for i = 1:length(compare_params_constraints)
        plot(numapps( : , i), param_markers{i}, "Color", 'k', 'LineWidth', 2);
        hold on;
    end
    ylabel('# Apps');
    xticklabels({'cache', 'hh', 'lb'});
%     lgd = legend(labels_constraints);
    lgd = legend({'least-constrained', 'most-constrained', 'least-constrained', 'most-constrained'});
    lgd.Location = 'northwest';
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('comparison_util_max_instance.png'));
end

if graphs(3) == 1
    L = cell(1, length(compare_params_constraints) * length(compare_params_workloads));
    num_wl = length(compare_params_workloads);
    num_constr = length(compare_params_constraints);
    grouped_data = zeros(num_constr, num_wl, PARAM_NUMAPPS * PARAM_NUMREPS);
    for k = 1:length(compare_params_workloads)
        for i = 1:length(compare_params_constraints)
            data = zeros(PARAM_NUMAPPS, PARAM_NUMREPS);
            for j = 1:PARAM_NUMREPS
                data_alloctime = readtable(sprintf( ...
                    'stats_g%d_n%d_%s_%s_%s/%d/alloctime.csv', ...
                    PARAM_GRANULARITY, ...
                    PARAM_NUMAPPS, ...
                    compare_params_workloads{k}, ...
                    PARAM_FIT, ...
                    compare_params_constraints{i}, ...
                    j - 1 ...
                ));
                data( : , j) = data_alloctime{ : , 1} * 1E3;
            end
    
            data(data == 0) = NaN;
    
            allocation_time = mean(data, 2);
            grouped_data(i, k, : ) = reshape(data, [PARAM_NUMAPPS*PARAM_NUMREPS, 1]);
        
%             plot(allocation_time, param_markers{i}, "Color", param_colors{k});
%             hold on;
    
            L((k-1)*length(compare_params_constraints)+i) = cellstr(sprintf('%s (%s)', labels_workloads{k}, compare_params_constraints{i}));
        end
    end

%     Y_avg = zeros(length(compare_params_constraints), length(compare_params_workloads));
%     Y_lb = zeros(length(compare_params_constraints), length(compare_params_workloads));
%     Y_ub = zeros(length(compare_params_constraints), length(compare_params_workloads));
% 
%     for i = 1:length(compare_params_workloads)
%         for j = 1:length(compare_params_constraints)
%             Y_avg(j, i) = nanmean(grouped_data((i - 1)*2+j, :));
%             Y_lb(j, i) = min(grouped_data((i - 1)*2+j, :));
%             Y_ub(j, i) = max(grouped_data((i - 1)*2+j, :));
%         end
%     end
% 
%     Y_neg = Y_avg - Y_lb;
%     Y_pos = Y_ub - Y_avg;
    
%     figure;
%     for i = 1:length(compare_params_constraints)
%         errorbar(1:length(compare_params_workloads), Y_avg(i, : ), Y_neg(i, : ), Y_pos(i, : ), 'LineWidth', 2);
%         hold on;
%     end
    
    figure;
    plotstyles_constr = {'compact', 'traditional'};
    for i = 1:num_constr
        X = reshape(grouped_data(i, :, :), [num_wl, PARAM_NUMAPPS * PARAM_NUMREPS]);
        boxplot(X', 'PlotStyle', plotstyles_constr{i});
        hold on;
        Xm = nanmedian(X, 2);
        plot(Xm, 'LineWidth', 1.5);
        hold on;
    end
    ylabel('Computation Time (ms)');
    xticklabels(labels_workloads);
%     xlabel('App #');
%     lgd = legend(L);
    lgd = legend(labels_constraints);
    lgd.Location = 'northwest';
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('comparison_allocation_time.png'));
end

% figure;
% L = cell(1, length(compare_params_constraints) * length(compare_params_workloads));
% for k = 1:length(compare_params_workloads)
%     for i = 1:length(compare_params_constraints)
%         data_utilization = readtable(sprintf( ...
%             'stats_g%d_n%d_%s_%s_%s/%d/utilization.csv', ...
%             PARAM_GRANULARITY, ...
%             PARAM_NUMAPPS, ...
%             compare_params_workloads{k}, ...
%             PARAM_FIT, ...
%             compare_params_constraints{i}, ...
%             PARAM_EXPID ...
%         ));
% 
%         utilization = data_utilization{ : , 1};
%         utilization(utilization == 0) = NaN;
%     
%         plot(utilization, param_markers{i}, "Color", param_colors{k});
%         hold on;
%         L((k-1)*length(compare_params_constraints)+i) = cellstr(sprintf('%s (%s)', compare_params_workloads{k}, compare_params_constraints{i}));
%     end
% end
% 
% ylabel('Utilization');
% xlabel('App #');
% lgd = legend(L);
% lgd.Location = 'southeast';
% set(gca, 'FontSize', 16);
% grid on;

% set(gcf, 'Position', get(0, 'Screensize'));

% saveas(gcf, sprintf('comparison_utilization_instance_%d.png', PARAM_EXPID));

if graphs(4) == 1
    figure;
    for i = 1:length(compare_params_constraints)
        utildata = zeros(PARAM_NUMREPS, PARAM_NUMAPPS);
        for j = 1:PARAM_NUMREPS
            data_utilization = readtable(sprintf( ...
                'stats_g%d_n%d_%s_%s_%s/%d/utilization.csv', ...
                PARAM_GRANULARITY, ...
                PARAM_NUMAPPS, ...
                'random', ...
                PARAM_FIT, ...
                compare_params_constraints{i}, ...
                j - 1 ...
            ));
            utilization = data_utilization{ : , 1};
            utilization(utilization == 0) = NaN;
            utildata( j , : ) = utilization;
        end
        util_ub = max(utildata, [], 1);
        util_lb = min(utildata, [], 1);
        util_avg = mean(utildata, 1);
        err_neg = util_avg - util_lb;
        err_pos = util_ub - util_avg;
%         X = [1:PARAM_NUMAPPS;1:PARAM_NUMAPPS];
%         X = X(:)';
%         Y = [util_lb; util_ub];
%         Y = Y(:)';
%         fill(X, Y, colors_light{i});
        errorbar(1:PARAM_NUMAPPS, util_avg, err_neg, err_pos);
        hold on;
    end
    ylabel('Utilization');
    xlabel('App #');
    lgd = legend(labels_constraints);
    lgd.Location = 'southeast';
    set(gca, 'FontSize', 16);
    grid on;
    
    saveas(gcf, sprintf('comparison_utilization_random.png'));
end