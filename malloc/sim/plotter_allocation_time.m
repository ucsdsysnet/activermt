clear;
clc;

addpath("../../ref/matlab_colormap/Colormaps");

load("colormap_apps.mat");

num_repeats = 10;
num_epochs = 500;

workloads = {'cacheread', 'telemetry', 'cheetahlb', 'mixed'};
schemes_granularity = {'128B', '256B', '512B', '1024B'};
schemes_constr = {'mc', 'lc'};

num_schemes_granularity = length(schemes_granularity);
num_schemes_constr = length(schemes_constr);
num_wl = length(workloads);

WL = {'Cache', 'HH', 'LB', 'Mixed'};

EWMA_ALPHA = 0.1;

for w = 1:num_wl
    figure;
    for s = 1:num_schemes_granularity
        data = readtable(sprintf('matlab/granularity/%s/%s/allocation_time.csv',workloads{w}, schemes_granularity{s}));
        plot(data{: , 1} / 1000, 'LineWidth', 1.5, 'Marker', 'square');
        hold on;
    end
    xlabel('App #');
    ylabel('Allocation Compute Time (sec)');
%     ylim([0 5]);
    lgd = legend(schemes_granularity, "NumColumns", 2);
    lgd.Location = 'northeast';
    set(gca, 'FontSize', 16);
    grid on;
    saveas(gcf, sprintf('matlab/granularity/granularity_%s.png', workloads{w}));
end

% for w = 1:num_wl
%     figure;
%     for s = 1:num_schemes_constr
%         data = readtable(sprintf('matlab/granularity/%s/%s/allocation_time.csv',workloads{w}, schemes_constr{s}));
%         fprintf("num data points for %s = %d\n", workloads{w}, size(data, 1));
%         plot(data{: , 1} / 1000, 'LineWidth', 1.5, 'Marker', 'square');
%         hold on;
%     end
%     xlabel('App #');
%     ylabel('Allocation Compute Time (sec)');
%     lgd = legend(schemes_constr);
%     lgd.Location = 'northeast';
%     xlim([0 500]);
%     ylim([0 1.2]);
%     set(gca, 'FontSize', 16);
%     grid on;
%     saveas(gcf, sprintf('matlab/granularity/constr_%s.png', workloads{w}));
% end

% schemes_constr = {'lc', 'mc'};
% linespecs = {':', '-', '-.', '--'};
% L = cell((num_wl - 1) * num_schemes_constr, 1);
% figure;
% for w = 1:num_wl-1
%     Y3 = zeros(num_schemes_constr, num_epochs);
%     for s = 1:num_schemes_constr
%         data = readtable(sprintf('matlab/granularity/%s/%s/allocation_time_scatter.csv',workloads{w}, schemes_constr{s}));
%         X = data{: , 1};
%         Y = data{: , 2} / 1000;
%         Y1 = reshape(Y, [num_epochs, num_repeats]);
%         Y1 = mean(Y1, 2);
%         Y3(s, : ) = Y1(:);
%         h = plot(Y3(s, : ), 'LineWidth', 2.5, 'LineStyle', linespecs{s}, 'Color', param_colors{w});
%         hold on;
%         L(num_schemes_constr * (w - 1) + s) = cellstr(sprintf("%s-%s", WL{w}, schemes_constr{s}));
%     end
% end
% xlabel('Epoch');
% ylabel('Allocation Compute Time (sec)');
% lgd = legend(L, "NumColumns", 3);
% lgd.Location = 'northwest';
% %     xlim([0 500]);
% ylim([0 1]);
% set(gca, 'FontSize', 16);
% grid on;
% saveas(gcf, 'matlab/granularity/constr_scatter_all.png');

% bg_alpha = 0.1;
% schemes_constr = {'mc', 'lc'};
% linespec_constr = {'.', '-'};
% w = num_wl;
% figure;
% Y3 = zeros(num_schemes_constr, num_epochs);
% for s = 1:num_schemes_constr
%     data = readtable(sprintf('matlab/granularity/%s/%s/allocation_time_scatter.csv',workloads{w}, schemes_constr{s}));
%     X = data{: , 1};
%     Y = data{: , 2} / 1000;
%     Y1 = reshape(Y, [num_epochs, num_repeats]);
%     Y1 = mean(Y1, 2);
%     Y2 = ewma(Y1, EWMA_ALPHA);
%     Y3(s, : ) = Y2(:);
%     scatter(X, Y, 15, "MarkerEdgeAlpha", bg_alpha, "MarkerFaceAlpha", bg_alpha);
%     hold on;
% end
% xlabel('Epoch');
% ylabel('Allocation Compute Time (sec)');
% lines = zeros(num_schemes_constr, 1);
% for s = 1:num_schemes_constr
%     p = plot(Y3(s, : ), 'LineWidth', 2.5, 'Color', param_colors{s});
%     lines(s) = p;
%     hold on;
% end
% ylim([0 1]);
% lgd = legend(lines, schemes_constr);
% lgd.Location = 'northwest';
% set(gca, 'FontSize', 16);
% grid on;
% saveas(gcf, sprintf('matlab/granularity/constr_scatter_%s.png', workloads{w}));

% L = cell(1, num_wl * num_schemes_constr);
% figure;
% idx = 1;
% for w = 1:num_wl
%     for s = 1:num_schemes_constr
%         data = readtable(sprintf('matlab/granularity/%s/%s/allocation_time.csv',workloads{w}, schemes_constr{s}));
%         plot(data{: , 1} / 1000, 'LineWidth', 1.5, 'Marker', 'square', 'Color', CMRmap(idx, :));
%         hold on;
%         L(num_schemes_constr * (w - 1) + s) = cellstr(sprintf("%s-%s", workloads{w}, schemes_constr{s}));
%         idx = idx + 1;
%     end
% end
% xlabel('App #');
% ylabel('Allocation Compute Time (sec)');
% lgd = legend(L, 'NumColumns', 2);
% lgd.Location = 'northwest';
% set(gca, 'FontSize', 16);
% grid on;
% saveas(gcf, 'matlab/granularity/constr_all.png');

% for s = 1:num_schemes_constr
%     figure;
%     for w = 1:num_wl
%         data = readtable(sprintf('matlab/granularity/%s/%s/allocation_time.csv',workloads{w}, schemes_constr{s}));
%         plot(data{: , 1} / 1000, 'LineWidth', 1.5, 'Marker', 'square');
%         hold on;
%     end
%     xlabel('App #');
%     ylabel('Allocation Compute Time (sec)');
%     lgd = legend(workloads);
%     lgd.Location = 'northwest';
%     set(gca, 'FontSize', 16);
%     grid on;
%     saveas(gcf, sprintf('matlab/granularity/constr_%s.png', schemes_constr{s}));
% end

% L = {'Cache', 'HH', 'LB', 'Mixed'};
% num_ticks = 500;
% cmap = viridis(num_wl * 2);
% % param_colors = {'#fef0d9','#fdcc8a','#fc8d59','#d7301f'};
% % param_colors = {[254,240,217], [253,204,138], [252,141,89], [215,48,31]};
% for s = 1:num_schemes_constr
%     param_colors = cell(num_wl, 1);
%     figure;
%     max_utils = zeros(num_wl, 1);
%     for w = 1:num_wl
%         data = readtable(sprintf('matlab/granularity/%s/%s/utilization.csv',workloads{w}, schemes_constr{s}));
%         data = data{ : , 1};
%         Y = data(1:num_ticks);
%         max_utils(w) = max(Y);
%         h = plot(Y, 'LineWidth', 1.5, 'Marker', 'square');
%         param_colors{w} = get(h, 'Color');
%         hold on;
%     end
% %     set(gca, 'ColorOrder', cmap);
%     xlabel('Epoch');
%     ylabel('Utilization');
%     for w = 1:num_wl
%         hline = refline([0 max_utils(w)]);
%         hline.Color = param_colors{w};
%         hline.LineWidth = 2;
%         hline.LineStyle = "--";
%     end
%     lgd = legend(L, "NumColumns", 2);
%     lgd.Location = 'southeast';
%     ylim([0 1]);
%     set(gca, 'FontSize', 16);
%     grid on;
%     saveas(gcf, sprintf('matlab/granularity/util_constr_%s.png', schemes_constr{s}));
% end
% save("colormap_apps.mat", "param_colors");