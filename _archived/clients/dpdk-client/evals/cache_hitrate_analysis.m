clear;
clc;

num_apps = 4;

ts_offset = 0;
% for i = 1:num_apps
%     data = csvread(sprintf('cache_stats_%d.csv', i - 1));
%     min_ts = min(data( : , 1 ));
%     if ts_offset == 0 || min_ts < ts_offset
%         ts_offset = min_ts;
%     end
% end

min_ts = -1;
max_ts = -1;

figure;
for i = 1:num_apps
    data = csvread(sprintf('cache_stats_%d.csv', i - 1));
    hitrate = data( : , 2) ./ data( : , 3);
    ts = (data( : , 1) - ts_offset) / 1000;
    tmp = min(ts);
    if min_ts < 0 || tmp < min_ts
        min_ts = tmp;
    end
    tmp = max(ts);
    if max_ts < 0 || tmp > max_ts
        max_ts = tmp;
    end
    plot(ts, hitrate);
    hold on;
end

xlabel('Time (sec)');
ylabel('Hitrate');
xlim([min_ts max_ts]);
ylim([0 1.5]);
legend(cellstr(num2str([1:num_apps]', 'App %-d')));
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'cache_hitrate.png');

figure;
for i = 1:num_apps
    data = csvread(sprintf('active_tx_stats_%d.csv', i));
    active_rate = data( : , 2) ./ data( : , 3);
    ts = (data( : , 1) - ts_offset) / 1000;
    ts(1) = 0;
    plot(ts, active_rate);
    hold on;
end

xlabel('Time (sec)');
ylabel('Fraction of Active Packets');
xlim([min_ts max_ts]);
ylim([0 1.5]);
legend(cellstr(num2str([1:num_apps]', 'App %-d')));
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'cache_activation.png');

% data_ref = csvread(sprintf('cache_stats_%d.csv', 0));
% data = csvread(sprintf('cache_stats_%d.csv', 3));
% ts_offset = min([data( : , 1 ); data_ref( : , 1)]);
% ts_ref = (data_ref( : , 1) - ts_offset) / 1000;
% ts = (data( : , 1) - ts_offset) / 1000;
% hitrate_ref = data_ref( : , 2) ./ data_ref( : , 3);
% hitrate = data( : , 2) ./ data( : , 3);
% 
% figure;
% plot(ts_ref, hitrate_ref);
% hold on;
% plot(ts, hitrate);