clear;
clc

data = csvread('results.csv');

duration_alloc = data( : , 1);
duration_check = data( : , 2);
duration_sync = data( : , 3);

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
