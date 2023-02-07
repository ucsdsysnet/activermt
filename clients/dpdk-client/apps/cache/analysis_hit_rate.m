clear;
clc;

NUM_APPS = 1;

figure;

mwa_filter = ones(1, 1000) * 0.001;
colors_light = {[1.0000    0.4118    0.1608], [0.0745    0.6235    1.0000], [0.3922    0.8314    0.0745], [1.0000    0.0745    0.6510]};
colors_dark = {[0.8510    0.3255    0.0980], [0    0.4471    0.7412], [0.4667    0.6745    0.1882], [0.6353    0.0784    0.1843]};

for i = 1:NUM_APPS
    data = readtable(sprintf('cache_rx_stats_%d.csv', i));
    X = data{ : , 1} * 1.0 / 1E3;
    hits = data{ : , 2};
    total = data{ : , 3};
    hit_rate = hits ./ total;
    hr_mwa = conv(hit_rate, mwa_filter);
    scatter(X, hit_rate, 3, colors_light{i});
    hold on;
    plot(X, hr_mwa(1:length(X)), 'Color', colors_dark{i}, 'LineWidth', 2.5);
    hold on;
end

ylabel('Hit Rate');
xlabel('Time (sec)');
lgd = legend(cellstr(num2str([1:NUM_APPS]', 'App %-d')));
lgd.Location = 'southeast';
set(gca,'XMinorTick','on','YMinorTick','on');
set(gca, 'FontSize', 16);
grid on;