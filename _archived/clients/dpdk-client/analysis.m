clear;
clc;

dpdk_rx = csvread('dpdk_ap4_stats_1.csv');
dpdk_tx = csvread('dpdk_ap4_stats_0.csv');

app_tx = csvread('kvapp_stats.csv');

figure;
plot(dpdk_rx( : , 2));
hold on;
plot(dpdk_tx( : , 3));
ylabel('Pkts/sec');
xlabel('Time');
legend('RX', 'TX');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'dpdk-tunnel-rates.png');

figure;
plot(app_tx( : , 3));
ylabel('Pkts/sec');
xlabel('Time');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'app-rates.png');