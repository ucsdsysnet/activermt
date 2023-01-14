clear;
clc;

data = readtable('activep4_allocations.csv');

apps = data{ : , 1};
allocation_times_ms = data{ : , 2} / 1E6;

figure;
plot(apps, allocation_times_ms, '-x');
% ylim([0 1000]);
xlabel('App #');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'allocation_times.png');