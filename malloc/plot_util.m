clear;
clc

load("utilization_exclusive_heuristic_i300_r1000_p0.500000.mat");
util_ex_hu = utilization;
load("utilization_exclusive_randomized_i300_r1000_p0.500000.mat");
util_ex_ra = utilization;
load("utilization_shared_heuristic_i300_r1000_p0.500000.mat");
util_sh_hu = utilization;
load("utilization_shared_randomized_i300_r1000_p0.500000.mat");
util_sh_ra = utilization;

figure
utilization = [util_ex_hu util_ex_ra util_sh_hu util_sh_ra];
boxplot(utilization);
title('Memory utilization');
ylim([0 1]);
ylabel('Utilization');
xticklabels({'ex / heu', 'ex / ran', 'sh / heu', 'sh / ran'});
set(gca, 'FontSize', 16);
grid on
saveas(gcf, 'memory_utilization.fig');
saveas(gcf, 'memory_utilization.png');

load("proportions_exclusive_heuristic_i300_r1000_p0.500000.mat");
totalloc_ex_hu = sum(fskew, 2);
load("proportions_exclusive_randomized_i300_r1000_p0.500000.mat");
totalloc_ex_ra = sum(fskew, 2);
load("proportions_shared_heuristic_i300_r1000_p0.500000.mat");
totalloc_sh_hu = sum(fskew, 2);
load("proportions_shared_randomized_i300_r1000_p0.500000.mat");
totalloc_sh_ra = sum(fskew, 2);

figure
totalloc = [totalloc_ex_hu totalloc_ex_ra totalloc_sh_hu totalloc_sh_ra];
boxplot(totalloc);
title('Total Allocations');
ylabel('#allocations');
xticklabels({'ex / heu', 'ex / ran', 'sh / heu', 'sh / ran'});
set(gca, 'FontSize', 16);
grid on
saveas(gcf, 'total_allocations.fig');
saveas(gcf, 'total_allocations.png');