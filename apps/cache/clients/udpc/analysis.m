clear;
clc;

num_apps = 4;

ts_min = -1;
ts_max = -1;

ts_ref = 0;
for i = 1:num_apps
    data = csvread(sprintf('kv_hits_misses_%d.csv', i));
    if ts_ref == 0 || data(1,1) < ts_ref
        ts_ref = data(1,1);
    end
    tmp = max(data( : , 1));
    if ts_max < 0 || tmp > ts_max
        ts_max = tmp;
    end
end

ts_min = 0;
ts_max = (ts_max - ts_ref) / 1E9;

figure;
for i = 1:num_apps
    data = csvread(sprintf('kv_hits_misses_%d.csv', i));
    ts_sec = (data( : , 1) - ts_ref) / 1E9;
    rx_hits = data( : , 2);
    rx_total = data( : , 3);
    hit_rate = rx_hits ./ rx_total;
%     plot(ts_sec, hit_rate);
    subplot(num_apps, 1, i);
    scatter(ts_sec, hit_rate, 3);
    ylabel('Hit Rate');
    xlim([ts_min ts_max]);
    ylim([0 1.5]);
    xlabel('Time (sec)');
    legend(sprintf('App %d', i));
    set(gca, 'FontSize', 16);
    grid on;
end

% legend(cellstr(num2str([1:num_apps]', 'App %-d')));

saveas(gcf, 'kv_hits_misses.png');