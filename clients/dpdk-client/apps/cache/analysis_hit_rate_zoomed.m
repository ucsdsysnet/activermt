clear;
clc;

SOURCE_DIR = './evals/mi_100ms_n_4_itvl_5_sec';
NUM_APPS = 4;

mwa_filter = ones(1, 1000) * 0.001;
colors_light = {[1.0000    0.4118    0.1608], [0.0745    0.6235    1.0000], [0.3922    0.8314    0.0745], [1.0000    0.0745    0.6510]};
colors_dark = {[0.8510    0.3255    0.0980], [0    0.4471    0.7412], [0.4667    0.6745    0.1882], [0.6353    0.0784    0.1843]};
line_styles = {'-', '--', ':', '-.'};

timeref = 1000;

for i = 1:NUM_APPS
    figure;
    data = readtable(sprintf('%s/cache_rx_stats_%d.csv', SOURCE_DIR, i));
    X = data{ : , 1} * 1.0 / 1E3;
    minX = min(X);
    if minX < timeref
        timeref = minX;
    end
    X = X - timeref;
    hits = data{ : , 2};
    total = data{ : , 3};
    hit_rate = hits ./ total;
    hrz = find(hit_rate == 0);
    Ts = X(min(hrz));
    hr_mwa = conv(hit_rate, mwa_filter);
    hr_stable = hr_mwa(min(hrz) + 3000);
    total_mwa = conv(total, mwa_filter);
    Xq = floor(X);
    Xu = unique(Xq);
    Rx = zeros(1, length(Xu));
    for j = 1:length(Xu)
        I = Xq == Xu(j);
        Rx(j) = sum(total(I));
    end
    scatter(X, hit_rate, 5, colors_dark{i});
    hold on;
    hline = refline(0, hr_stable);
    hline.Color = 'k';
    hline.LineWidth = 2;
%     hold on;
%     plot(X, hr_mwa(1:length(X)), '-', 'Color', colors_dark{i}, 'LineWidth', 2);
    ylabel('Hit Rate');
    xlabel('Time (sec)');
    xlim([Ts, Ts + 1]);
%     lgd = legend('Per-ms hit-rate', '1-sec MWA');
%     lgd.Location = 'southeast';
    set(gca,'XMinorTick','on','YMinorTick','on');
    set(gca, 'FontSize', 16);
    grid on;
    saveas(gcf, sprintf('dpdk_cache_hit_rate_n_%d_zoomed_app_%d.png', NUM_APPS, i));
end