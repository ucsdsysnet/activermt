clear;
clc;

data_allocations = readtable('activep4_allocations.csv');
data_snapshots = readtable('activep4_snapshots.csv');

apps_allocations = data_allocations{ : , 1};
allocation_times_ms = data_allocations{ : , 2} / 1E6;

apps_snapshots = data_snapshots{ : , 1};
snapshot_times = data_snapshots{ : , 2};
num_snapshots = data_snapshots{ : , 3};

num_apps = size(data_allocations, 1);

figure;
yyaxis left;
plot(apps_allocations, allocation_times_ms, '-square');
hold on;
plot(apps_snapshots, snapshot_times, '-x');
ylabel('Time (ms)');
yyaxis right;
plot(apps_snapshots, num_snapshots, '-o');
% set(gca, 'YTick', 0:max(num_snapshots));
ylabel('# Snapshots');
xlabel('App #');
lgd = legend('Allocation', 'Snapshot');
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('allocation_snapshot_timings_n%d.png', num_apps));

% swdata = readtable('allocation_times_controller.csv');
% swapps = swdata{ : , 1};
% sw_allocation_times_ms = swdata{ : , 2};
% 
% figure;
% plot(apps, allocation_times_ms, '-x');
% hold on;
% plot(swapps, sw_allocation_times_ms, '-o');
% % ylim([0 1000]);
% xlabel('App #');
% ylabel('Allocation Time (ms)');
% set(gca, 'FontSize', 16);
% grid on;
% lgd = legend('Client', 'Switch');
% lgd.Location = 'northwest';
% 
% saveas(gcf, 'allocation_times_compare.png');