clear;
clc;

BASE_PATH_INELASTIC = '../../malloc/evals/fit/wf/inelastic_cache';
BASE_PATH_ELASTIC = '../../malloc/evals/fit/wf/elastic_cache';
OUTPUT_PATH = 'figures/allocator/comparison';

NUM_STAGES = 20;
PARAM_GRANULARITY = 256;
PARAM_NUMAPPS = 128;
PARAM_NUMEXP = 100;

allocation_time_ms_inelastic = zeros(PARAM_NUMAPPS, PARAM_NUMEXP);
allocation_time_ms_elastic = zeros(PARAM_NUMAPPS, PARAM_NUMEXP);
    
for i = 1:PARAM_NUMEXP

    exp_id = i - 1;
    
    data_alloctime_inelastic = readtable(sprintf( ...
        '%s/stats_g%d_n%d/%d/alloctime.csv', ...
        BASE_PATH_INELASTIC, ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        exp_id ...
    ));

    data_alloctime_elastic = readtable(sprintf( ...
        '%s/stats_g%d_n%d/%d/alloctime.csv', ...
        BASE_PATH_ELASTIC, ...
        PARAM_GRANULARITY, ...
        PARAM_NUMAPPS, ...
        exp_id ...
    ));

    allocation_time_ms_inelastic( : , i) = data_alloctime_inelastic{ : , 1} * 1E3;
    allocation_time_ms_elastic( : , i) = data_alloctime_elastic{ : , 1} * 1E3;

end

allocation_time_ms_inelastic_median = median(allocation_time_ms_inelastic, 2);
allocation_time_ms_elastic_median = median(allocation_time_ms_elastic, 2);

figure;
plot(allocation_time_ms_inelastic_median, '-x');
hold on;
plot(allocation_time_ms_elastic_median, '-x');
xlabel('App #');
ylabel('Allocation Time (ms)');
lgd = legend('Inelastic Cache', 'Elastic Cache');
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('%s/online_allocation_time_d%d_n%d.png', OUTPUT_PATH, PARAM_GRANULARITY, PARAM_NUMAPPS));