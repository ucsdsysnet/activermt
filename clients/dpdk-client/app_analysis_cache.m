clear;
clc;

APP_ID = 0;

data = readtable(sprintf('cache_rx_stats_%d.csv', APP_ID));

time_ms = data{ : , 1};
hit_counts = data{ : , 2};
rx_counts = data{ : , 3};

hit_rate = hit_counts ./ rx_counts;

time_sec = floor(time_ms / 1E3);
unique_ts = unique(time_sec);
rx_custom = zeros(1, length(unique_ts));
hits_custom = zeros(1, length(unique_ts));

for i = 1:length(unique_ts)
    I = time_sec == unique_ts(i);
    hits_custom(i) = sum(hit_counts(I));
    rx_custom(i) = sum(rx_counts(I));
end

hit_rate_custom = hits_custom ./ rx_custom;

figure;
plot(unique_ts, hit_rate_custom, '-square');
hold on;
plot(time_sec, hit_rate, '-o');
xlabel('Time (sec)');
ylabel('HIT RATE');
set(gca, 'FontSize', 16);
grid on;