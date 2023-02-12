clear;
clc;

data = readtable('results_allocation_times.csv');

FID = data{ : , 1};
time_ns = data{ : , 2};

time_ms = time_ns / 1E6;

figure;
plot(FID, time_ms, '-square');
xlabel('FID');
ylabel('Allocation Time (ms)');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'allocation_time_duration_based.png');