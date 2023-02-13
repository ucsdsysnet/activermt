clear;
clc;

data_client = readtable('results_allocation_times.csv');
data_controller = readtable('results_controller.csv');

FID = data_client{ : , 1};
allocation_time_ns = data_client{ : , 2};
snapshot_time_ns = data_client{ : , 3};

allocation_time_ms = allocation_time_ns / 1E6;
snapshot_time_ms = snapshot_time_ns / 1E6;

figure;
% plot(FID, allocation_time_ms, '-square');
plot(data_controller{ : , 1}, data_controller{ : , 2}, '-square');
hold on;
plot(FID, snapshot_time_ms, '-x');
ylabel('Total Time (ms)');
xlabel('FID');
lgd = legend('Allocation', 'Snapshot');
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'allocation_time_duration_based.png');