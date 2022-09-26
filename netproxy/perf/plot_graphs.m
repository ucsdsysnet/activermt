clear;
clc;

data = readtable('direct_vs_tun.csv');
data = table2array(data) / 1E9;

figure;
plot(data( : , 1), '-square');
hold on;
plot(data( : , 2), '-square');
xlabel('Time (sec)');
ylabel('Throughput (Gbps)');
title('Overhead of TUN (iperf)');
legend('w/o TUN', 'w/ TUN');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'tun_overhead_iperf.png');