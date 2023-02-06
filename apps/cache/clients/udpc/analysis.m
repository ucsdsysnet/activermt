clear;
clc;

SAMPLING_GRANULARITY_MS = 1;
HR_PLOT_GRANULARITY = 10;

num_apps = 4;

colors_light = {[1.0000    0.4118    0.1608], [0.0745    0.6235    1.0000], [0.3922    0.8314    0.0745], [1.0000    0.0745    0.6510]};
colors_dark = {[0.8510    0.3255    0.0980], [0    0.4471    0.7412], [0.4667    0.6745    0.1882], [0.6353    0.0784    0.1843]};
params_colors = {'b', 'g', 'r', 'm'};

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

mwa_filter = ones(1, 1000) * 0.001;

figure;
for i = 1:num_apps
    data = csvread(sprintf('kv_hits_misses_%d.csv', i));
    ts_sec = (data( : , 1) - ts_ref) / 1E9;
    rx_hits = data( : , 2);
    rx_total = data( : , 3);
    ts_quantized_sec = floor(ts_sec);
    ts_quantized_custom = floor(ts_sec * HR_PLOT_GRANULARITY);
    ts_unique_sec = unique(ts_quantized_sec);
    ts_unique_custom = unique(ts_quantized_custom);
    rx_rate_sec = zeros(1, length(ts_unique_sec));
    hit_rate_sec = zeros(1, length(ts_unique_sec));
    hit_rate_custom = zeros(1, length(ts_unique_custom));
    for j = 1:length(ts_unique_sec)
        I = ts_quantized_sec == ts_unique_sec(j);
        rx_rate_sec(j) = sum(rx_total(I));
        hit_rate_sec(j) = sum(rx_hits(I)) / rx_rate_sec(j);
    end
    for j = 1:length(ts_unique_custom)
        I = ts_unique_custom == ts_unique_custom(j);
        hit_rate_custom(j) = sum(rx_hits(I)) * 1.0 / sum(rx_total(I));
    end
    hit_rate = rx_hits ./ rx_total;
    hr_mwa = conv(hit_rate, mwa_filter);
%     yyaxis left;
%     plot(ts_unique_sec, rx_rate_sec, '--square', 'Color', params_colors{i});
%     hold on;
%     yyaxis right;
%     scatter(ts_sec, hit_rate, 3, 'o', 'MarkerEdgeColor', colors_light{i});
%     hold on;
%     plot(ts_unique_sec, hit_rate_sec, '-square', 'Color', params_colors{i});
%     plot(ts_unique_custom / HR_PLOT_GRANULARITY, hit_rate_custom, '-o', 'MarkerSize', 3);
%     hold on;
    plot(ts_sec, hr_mwa(1:length(ts_sec)), '-', 'Color', colors_dark{i}, 'LineWidth', 2.5);
    hold on;
%     ylim([0 1.5]);
end

% yyaxis left;
% ylabel('RX (Pkts/Sec)');
% yyaxis right;
ylabel('Hit Rate');
% xlim([ts_min ts_max]);
% xticks(0:0.1:ceil(max(ts_sec)));
xlabel('Time (sec)');
% legend(sprintf('App %d', i));
set(gca,'XMinorTick','on','YMinorTick','on');
set(gca, 'FontSize', 16);
grid on;

% lgd = legend(cellstr(num2str(sort([1:num_apps, 1:num_apps])', 'App %-d')));
lgd = legend(cellstr(num2str([1:num_apps]', 'App %-d')));
lgd.Location = 'southeast';

saveas(gcf, sprintf('kv_hits_misses_n%d.png', num_apps));