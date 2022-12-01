clear;
clc;

num_apps = 4;

ts_ref = 0;
for i = 1:num_apps
    data = csvread(sprintf('kv_hits_misses_%d.csv', i));
    if ts_ref == 0 || data(1,1) < ts_ref
        ts_ref = data(1,1);
    end
end

figure;
for i = 1:num_apps
    data = csvread(sprintf('kv_hits_misses_%d.csv', i));
    ts_sec = (data( : , 1) - ts_ref) / 1E9;
    rx_hits = data( : , 2);
    rx_total = data( : , 3);
    hit_rate = rx_hits ./ rx_total;
    plot(ts_sec, hit_rate);
    hold on;
end

xlabel('Time (sec)');
ylabel('Hit Rate');
ylim([0 1.5]);
set(gca, 'FontSize', 16);
legend(cellstr(num2str([1:num_apps]', 'App %-d')));
grid on;

saveas(gcf, 'kv_hits_misses.png');