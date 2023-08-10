clear;
clc;

NUM_STAGES = 20;
PARAM_GRANULARITY = 368;
PARAM_NUMAPPS = 128;
PARAM_EXPID = 0;
PARAM_WORKLOAD = 'cache';
% PARAM_FIT = 'wf';
PARAM_FIT = 'min';
PARAM_CONSTR = 'mc';

metrics = [0 4];
markers = {'-x', '-o'};
metrics_str = {'utilization (wf)', 'reallocations (min)'};

avg_reallocations = zeros(1, length(metrics));

figure;
for i = 1:length(metrics)
    metric = metrics(i);
%     if metric == 0
%         PARAM_FIT = 'bf';
%     else
%         PARAM_FIT = 'wf';
%     end
    data_costs = readtable(sprintf( ...
        'stats_g%d_n%d_%s_%s_%s_%d/%d/costs.csv', ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        PARAM_WORKLOAD, ...
        PARAM_FIT, ...
        PARAM_CONSTR, ...
        metric, ...
        PARAM_EXPID ...
    ));
    avg_reallocations(i) = mean(data_costs{:, 1});
%     plot(data_costs{ : , 1}, markers{i});
    cdfplot(data_costs{ : , 1});
    hold on;
end

xlabel('# reallocations');
% lgd = legend(cellstr(num2str(metrics', 'metric=%-d')));
lgd = legend(cellstr(metrics_str));
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, sprintf('objective_comparison_wf.png'));
% saveas(gcf, sprintf('objective_comparison_wf_timeseries.png'));