clear;
clc;

data_app = csvread('redisapp_stats_redis.csv');
data_tun = csvread('tuntap_stats_redis.csv');
data_direct = csvread('redisapp_stats_notun.csv');

data_app = data_app(data_app( : , 3) > 0, 3);
data_tun = data_tun(data_tun( : , 3) > 0, 3);
data_direct = data_direct(data_direct( : , 3) > 0, 3);

num_samples = min([ length(data_direct), length(data_tun), length(data_app) ]);

data = zeros(num_samples, 3);

data( : , 1) = datasample(data_app, num_samples);
data( : , 2) = datasample(data_tun, num_samples);
data( : , 3) = datasample(data_direct, num_samples);

figure;
boxplot(data);
xticks(1:3);
xticklabels({'Redis (w/ TUN)', 'TUN relay', 'Redis (w/o TUN)'});
ylabel('Requests/sec');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'redis_tun_direct.png');