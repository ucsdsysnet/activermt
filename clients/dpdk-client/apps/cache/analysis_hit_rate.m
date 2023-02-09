clear;
clc;

NUM_APPS = 1;

figure;

mwa_filter = ones(1, 1000) * 0.001;
colors_light = {[1.0000    0.4118    0.1608], [0.0745    0.6235    1.0000], [0.3922    0.8314    0.0745], [1.0000    0.0745    0.6510]};
colors_dark = {[0.8510    0.3255    0.0980], [0    0.4471    0.7412], [0.4667    0.6745    0.1882], [0.6353    0.0784    0.1843]};
line_styles = {'-', '--', ':', '-.'};

timeref = 1000;

for i = 1:NUM_APPS
    data = readtable(sprintf('cache_rx_stats_%d.csv', i));
    X = data{ : , 1} * 1.0 / 1E3;
    minX = min(X);
    if minX < timeref
        timeref = minX;
    end
    X = X - timeref;
    hits = data{ : , 2};
    total = data{ : , 3};
    hit_rate = hits ./ total;
    hr_mwa = conv(hit_rate, mwa_filter);
    total_mwa = conv(total, mwa_filter);
    Xq = floor(X);
    Xu = unique(Xq);
    Rx = zeros(1, length(Xu));
    for j = 1:length(Xu)
        I = Xq == Xu(j);
        Rx(j) = sum(total(I));
    end
%     scatter(X, hit_rate, 3, colors_light{i});
%     hold on;
    yyaxis left;
    plot(X, hr_mwa(1:length(X)), '-', 'Color', colors_dark{i}, 'LineWidth', 2);
    hold on;
    yyaxis right;
    plot(Xu, Rx , '--square', 'Color', colors_light{i}, 'LineWidth', 2);
    hold on;
end

% plots = get(gca, 'Children');
% for i = 1:NUM_APPS
%     if mod(i, 2) == 0
%         tmp = plots(i);
%         plots(i) = plots(NUM_APPS + i - 1);
%         plots(NUM_APPS + i - 1) = tmp;
%     end
% end
% set(gca, 'Children', plots);

yyaxis left;
ylabel('Hit Rate');
yyaxis right;
ylabel('RX Pkts/sec');
xlabel('Time (sec)');
legend_params = [1:NUM_APPS,1:NUM_APPS];
lgd = legend(cellstr(num2str(legend_params', 'App %-d')));
lgd.Location = 'southeast';
set(gca,'XMinorTick','on','YMinorTick','on');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('dpdk_cache_hit_rate_n_%d.png', NUM_APPS));