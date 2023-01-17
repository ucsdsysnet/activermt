clear;
clc;

data = readtable('activep4_allocations.csv');

apps = data{ : , 1};
allocation_times_ms = data{ : , 2} / 1E6;

swdata = readtable('switch_allocation_times_32.csv');
swapps = swdata{ : , 1};
sw_allocation_times_ms = swdata{ : , 2};

figure;
plot(apps, allocation_times_ms, '-x');
hold on;
plot(swapps, sw_allocation_times_ms, '-o');
% ylim([0 1000]);
xlabel('App #');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;
lgd = legend('Client', 'Switch');
lgd.Location = 'northwest';

saveas(gcf, 'allocation_times_compare.png');