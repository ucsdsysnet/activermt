clear;
clc

data = csvread('results.csv');

duration_sync = data( : , 3);

figure
boxplot(duration_sync / 1E6);
title('Memory (dataplane) sync time for 64k objects');
ylabel('Memory sync time (ms)');
set(gca, 'FontSize', 16);
xticks([]);
grid on

saveas(gcf, 'sync_time.png');