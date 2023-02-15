clear;
clc;

SOURCE_DIR = '.';
ALPHA = 0.01;

figure;

mwa_filter = ones(1, 1000) * 0.001;
colors_light = {[1.0000    0.4118    0.1608], [0.0745    0.6235    1.0000], [0.3922    0.8314    0.0745], [1.0000    0.0745    0.6510]};
colors_dark = {[0.8510    0.3255    0.0980], [0    0.4471    0.7412], [0.4667    0.6745    0.1882], [0.6353    0.0784    0.1843]};
line_styles = {'-', '--', ':', '-.'};

timeref = 1000;

ctxt_times = csvread('context_switch_time_ms.csv');

ctxtsw_start = ctxt_times(1);
ctxtsw_end = ctxt_times(2);

data = readtable(sprintf('%s/cache_rx_stats_1.csv', SOURCE_DIR));
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
ewma_hr = zeros(size(hit_rate));
ewma_hr(1) = hit_rate(1);
for i = 2:length(hit_rate)
    ewma_hr(i) = ALPHA * hit_rate(i) + (1-ALPHA)*ewma_hr(i-1);
end
ewma_total = zeros(size(total));
ewma_total(1) = total(1);
for i = 2:length(total)
    ewma_total(i) = ALPHA * total(i) + (1-ALPHA)*ewma_total(i-1);
end
Xq = floor(X);
Xu = unique(Xq);
Rx = zeros(1, length(Xu));
for j = 1:length(Xu)
    I = Xq == Xu(j);
    Rx(j) = sum(total(I));
end
scatter(X, hit_rate, 20, colors_light{2}, "diamond");
hold on;
% yyaxis left;
% plot(X, hr_mwa(1:length(X)), '-', 'LineWidth', 2);
plot(X, ewma_hr, '-', 'LineWidth', 2);
% hold on;
% yyaxis right;
% plot(Xu, Rx , '--square', 'LineWidth', 2);
% plot(X, total_mwa(1:length(X)) , '--');
% plot(X, ewma_total , '--', 'LineWidth', 2);
% hold on;

ctxtsw_start = ctxtsw_start / 1E3 - timeref;
ctxtsw_end = ctxtsw_end / 1E3 - timeref;

h = xline([ctxtsw_start ctxtsw_end], '--', {'context switch begin', 'context switch end'}, 'LabelHorizontalAlignment', 'left', 'LineWidth', 3, 'FontSize', 12);

xlim([0 6]);

% yyaxis left;
ylim([0 1]);
ylabel('Hit Rate');
% yyaxis right;
% ylabel('RX #Pkts');
xlabel('Time (sec)');
set(gca,'XMinorTick','on','YMinorTick','on');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('dpdk_cache_hit_rate_modular_hr.png'));