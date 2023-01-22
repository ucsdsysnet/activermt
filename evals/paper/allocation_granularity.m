clear;
clc;

BASE_PATH = '../../malloc/evals/granularity/32';
OUTPUT_PATH = 'figures/granularity';

NUM_DATA_POINTS = 100;
DEFAULT_NUMAPPS = 32;

param_granularity = [16 32 64 128 256];

% data_cache = getAllocationTimesByGranularity('cache', 'elastic_cache', param_granularity);
% figure;
% boxplot(data_cache);
% xticklabels(param_granularity);
% xlabel('Granularity (blocks)');
% ylabel('Allocation Time (ms)');
% set(gca, 'FontSize', 16);
% grid on;
% saveas(gcf, sprintf('%s/granularity_allocation_time_n%d_cache.png', OUTPUT_PATH, DEFAULT_NUMAPPS));
% 
% data_hh = getAllocationTimesByGranularity('freqitem', 'inelastic_hh', param_granularity);
% figure;
% boxplot(data_hh);
% xticklabels(param_granularity);
% xlabel('Granularity (blocks)');
% ylabel('Allocation Time (ms)');
% set(gca, 'FontSize', 16);
% grid on;
% saveas(gcf, sprintf('%s/granularity_allocation_time_n%d_hh.png', OUTPUT_PATH, DEFAULT_NUMAPPS));
% 
% data_lb = getAllocationTimesByGranularity('cheetahlb', 'inelastic_lb', param_granularity);
% figure;
% boxplot(data_lb);
% xticklabels(param_granularity);
% xlabel('Granularity (blocks)');
% ylabel('Allocation Time (ms)');
% set(gca, 'FontSize', 16);
% grid on;
% saveas(gcf, sprintf('%s/granularity_allocation_time_n%d_lb.png', OUTPUT_PATH, DEFAULT_NUMAPPS));

data_mixed = getAllocationTimesByGranularity('random', 'mixed', param_granularity);
figure;
boxplot(data_mixed);
xticklabels(param_granularity);
xlabel('Granularity (blocks)');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('%s/granularity_allocation_time_n%d_mixed.png', OUTPUT_PATH, DEFAULT_NUMAPPS));