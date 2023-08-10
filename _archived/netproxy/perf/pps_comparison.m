clear;
clc;

data_app = csvread('redisapp_stats.csv');
data_tun = csvread('tuntap_stats.csv');

ts_baseline = min(data_tun( : , 1));

ts_app = ((data_app( : , 1) - ts_baseline) * 1E9 + data_app( : , 2)) / 1E9;
ts_tun = ((data_tun( : , 1) - ts_baseline) * 1E9 + data_tun( : , 2)) / 1E9;

figure;
plot(ts_tun, data_tun( : , 3), '-square');
hold on;
plot(ts_app, data_app( : , 3), '-square');
xlabel('Time (sec)');
ylabel('Pkts/sec');
legend('TUN', 'App');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'pps_compare_redis.png');