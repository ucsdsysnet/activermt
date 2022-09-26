clear;
clc;

data = readtable('direct_vs_tun_vs_active.csv');
data = table2array(data) / 1E9;

figure;
boxplot(data);
xticks(1:3);
xticklabels({'w/o TUN', 'w/ TUN', 'w/ Active'});
ylabel('Throughput (Gbps)');
title('Overhead of active filtering');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'active_tun_overhead_iperf.png');