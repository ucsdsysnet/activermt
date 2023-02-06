clear;
clc;

PORT_ETH = 0;
PORT_VETH = 1;

stats_eth = readtable(sprintf('dpdk_ap4_stats_%d.csv', PORT_ETH));
% stats_veth = readtable(sprintf('dpdk_ap4_stats_%d.csv', PORT_VETH));

ts_eth_sec = stats_eth{ : , 1} / 1E9;
% ts_veth_sec = stats_veth{ : , 1} / 1E9;

% ymax = max([ stats_eth{ : , 3} ; stats_eth{ : , 2} ; stats_veth{ : , 3 } ; stats_veth{ : , 2}]);
ymax = max([ stats_eth{ : , 3} ; stats_eth{ : , 2}]);

figure;
% yyaxis left;
plot(ts_eth_sec, stats_eth{ : , 2}, '-square');
hold on;
plot(ts_eth_sec, stats_eth{ : , 3}, '-o');
ylim([0 ymax]);
ylabel('# packets (eth)');
% yyaxis right;
% plot(ts_veth_sec, stats_veth{ : , 2}, '--square');
% hold on;
% plot(ts_veth_sec, stats_veth{ : , 3}, '--o');
% ylim([0 ymax]);
% ylabel('# packets (veth)');
xlabel('Time (sec)');
% lgd = legend('RX (eth)', 'TX (eth)', 'RX (veth)', 'TX (veth)');
lgd = legend('RX (eth)', 'TX (eth)');
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'dpdk_filter_perf.png');