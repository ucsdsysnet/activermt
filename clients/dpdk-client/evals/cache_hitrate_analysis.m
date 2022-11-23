clear;
clc;

num_apps = 1;

ts_offset = 0;
for i = 1:num_apps
    data = csvread(sprintf('cache_stats_%d.csv', i - 1));
    min_ts = min(data( : , 1 ));
    if ts_offset == 0 || min_ts < ts_offset
        ts_offset = min_ts;
    end
end

figure;
for i = 1:num_apps
    data = csvread(sprintf('cache_stats_%d.csv', i - 1));
    hitrate = data( : , 2) ./ data( : , 3);
    ts = (data( : , 1) - ts_offset) / 1000;
    plot(ts, hitrate);
    hold on;
end

xlabel('Time (sec)');
ylabel('Hitrate');
ylim([0 1]);
legend(cellstr(num2str([1:num_apps]', 'App %-d')));
set(gca, 'FontSize', 16);
grid on;