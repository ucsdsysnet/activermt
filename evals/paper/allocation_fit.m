clear;
clc;

BASE_PATH = '../../malloc/evals/fit/data';
OUTPUT_PATH = 'figures/fit';

GRANULARITY = 256;
NUM_DATA_POINTS = 100;
NUM_APPS = 128;

params_workloads = {'cache', 'freqitem', 'cheetahlb', 'random'};
params_fit = {'ff', 'wf', 'bf'};

markers = {'--x', '-o', '--square'};

for i = 1:size(params_workloads, 2)
    figure;
    for j = 1:size(params_fit, 2)
        exp_id = randsample(NUM_DATA_POINTS, 1) - 1;
        data_utilization = readtable(sprintf( ...
            '%s/stats_g%d_n%d_%s_%s/%d/utilization.csv', ...
            BASE_PATH, ...
            GRANULARITY, ...
            NUM_APPS, ...
            params_workloads{i}, ...
            params_fit{j}, ...
            exp_id ...
        ));
        data_utilization = table2array(data_utilization);
%         data_utilization(data_utilization == 0) = NaN;
        plot(data_utilization, markers{j});
        hold on;
    end
    xlabel('App #');
    ylabel('Utilization');
    lgd = legend(params_fit);
    lgd.Location = 'southeast';
    set(gca, 'FontSize', 16);
    grid on;
    saveas(gcf, sprintf('%s/utilization_d%d_n%d_%s.png', OUTPUT_PATH, GRANULARITY, NUM_APPS, params_workloads{i}));
end