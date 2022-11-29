clear;
clc;

data = csvread('kv_hits_misses.csv');

ts_ref = data(1,1);

ts_sec = (data( : , 1) - ts_ref) / 1E9;
rx_hits = data( : , 2);
rx_total = data( : , 3);
hit_rate = rx_hits ./ rx_total;

figure;
plot(ts_sec, hit_rate);
xlabel('Time (sec)');
ylabel('Hit Rate');
title('KV App');
ylim([0 1.5]);
set(gca, 'FontSize', 16);
grid on;