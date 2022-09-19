clear;
clc

data_nosnapshot = csvread('results_nosync.csv');
data_snapshot_cp = csvread('results_sync.csv');
data_snapshot_dp = csvread('results_sync_remote.csv');

data = zeros(size(data_nosnapshot, 1), 3);
data( : , 1) = data_nosnapshot( : , 1) / 1E6;
data( : , 2) = data_snapshot_dp( : , 1) / 1E6;
data( : , 3) = data_snapshot_cp( : , 1) / 1E6;

figure;
set(gcf,'position',[300, 300, 480, 360]);
boxplot(data / 1E3);
title('Allocation Time');
ylabel('Time (sec)');
% set(gca, 'YScale', 'log');
set(gca, 'FontSize', 16);
xticklabels({"w/o snapshots", 'w/ DP snapshot', 'w/ CP snapshot'});
grid on;
saveas(gcf, 'allocation_time.png');

% data = csvread('results.csv');
% 
% duration_alloc = data( : , 1);
% duration_check = data( : , 2);
% duration_sync = data( : , 3);

% figure
% boxplot(duration_sync / 1E6);
% title('Memory (dataplane) sync time for 64k objects');
% ylabel('Memory sync time (ms)');
% set(gca, 'FontSize', 16);
% xticks([]);
% grid on
% 
% saveas(gcf, 'sync_time.png');

% figure
% boxplot(duration_alloc / 1E9);
% title('Allocation time (w/ control plane sync)');
% ylabel('Time (sec)');
% set(gca, 'FontSize', 16);
% xticks([]);
% grid on
% 
% saveas(gcf, 'alloc_time.png');

% figure
% boxplot(duration_check / 1E6);
% title('Allocation check time');
% ylabel('Time (ms)');
% set(gca, 'FontSize', 16);
% xticks([]);
% grid on
% 
% saveas(gcf, 'check_time.png');

% figure
% boxplot(duration_alloc / 1E6);
% title('Allocation time (w/o sync)');
% ylabel('Time (sec)');
% set(gca, 'FontSize', 16);
% xticks([]);
% grid on
% 
% saveas(gcf, 'alloc_time_nosync.png');

% figure
% boxplot(duration_alloc / 1E9);
% title('Allocation time (w/ remote sync)');
% ylabel('Time (sec)');
% set(gca, 'FontSize', 16);
% xticks([]);
% grid on
% 
% saveas(gcf, 'alloc_time_remote_sync.png');
