clear;
clc;

NUM_MEMIDX = 2;
DEFAULT_GRANULARITY = 256;
NUM_DATA_POINTS = 100;

statnames = ['enumsizes', 'alloctime', 'costs', 'utilization', 'appnames', 'stages'];

% params = [32 64 128 256];
params = [128];

time_wc = zeros(NUM_DATA_POINTS, length(params));
time_bc = zeros(NUM_DATA_POINTS, length(params));

figure;
% set(gcf,'position',[300, 300, 1100, 400]);
for k = 1:length(params)

    num_apps = params(k);

%     data_stageidx = zeros(NUM_DATA_POINTS, num_apps, NUM_MEMIDX);
    data_time_ms = zeros(NUM_DATA_POINTS, num_apps);
    data_cost = zeros(NUM_DATA_POINTS, num_apps);
    data_util = zeros(NUM_DATA_POINTS, num_apps);
    
    series_data = zeros(3, num_apps);

    dataset_name = sprintf('stats_g%d_n%d', DEFAULT_GRANULARITY, num_apps);
    
    for i = 1:NUM_DATA_POINTS
%         data_stageidx(i, :, : ) = csvread(sprintf('%s/%d/stages.csv', dataset_name, i - 1));
        data_time_ms(i, : ) = csvread(sprintf('%s/%d/alloctime.csv', dataset_name, i - 1)) * 1E3;
        data_cost(i, : ) = csvread(sprintf('%s/%d/costs.csv', dataset_name, i - 1));
        data_util(i, : ) = csvread(sprintf('%s/%d/utilization.csv', dataset_name, i - 1));
    end
    
    for i = 1:num_apps
        series_data(1, i) = median(data_time_ms(:, i ));
        series_data(2, i) = median(data_cost(:, i ));
        series_data(3, i) = median(data_util(:, i ));
    end

    time_wc(: , k) = max(data_time_ms, [], 2);
    time_bc(: , k) = min(data_time_ms, [], 2);
    
    % boxplot(data_time_ms);
    subplot(2, 1, 1);
    plot(series_data(1, : ), '-x');
    hold on;

%     subplot(3, 1, 2);
%     plot(series_data(2, : ), '-x');
%     hold on;

    subplot(2, 1, 2);
    plot(series_data(3, : ), '-x');
    hold on;
end

subplot(2,1,1);
ylim([0 10]);
xlabel('Online sequence #');
ylabel('Allocation Time (ms)');
legend(cellstr(num2str(params', 'N=%-d')));
set(gca, 'FontSize', 16);
grid on;

% subplot(3,1,2);
% % ylim([0 10]);
% xlabel('Online sequence #');
% ylabel('Reallocation Cost');
% legend(cellstr(num2str(params', 'N=%-d')));
% set(gca, 'FontSize', 16);
% grid on;

subplot(2,1,2);
% ylim([0 10]);
xlabel('Online sequence #');
ylabel('Utilization');
legend(cellstr(num2str(params', 'N=%-d')));
set(gca, 'FontSize', 16);
grid on;

set(gcf, 'Position', get(0, 'Screensize'));
saveas(gcf, 'allocation_time_series_fixed_granularity.png');

figure;
plot(params, median(time_wc, 1), '-x');
% boxplot(time_wc);
hold on
plot(params, median(time_bc, 1), '-x');
% boxplot(time_bc);
% xticklabels(params);
xticks(params);
xlabel('# Apps');
ylabel('Allocation Time (ms)');
lgd = legend('Worst case', 'Best case');
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'allocation_time_fixed_granularity_varapps.png');