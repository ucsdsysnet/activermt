clear;
clc;

DEFAULT_GRANULARITY = 256;
NUM_DATA_POINTS = 100;

params = [32 64 128 256];

time_wc = zeros(NUM_DATA_POINTS, length(params));
time_bc = zeros(NUM_DATA_POINTS, length(params));

figure;
set(gcf,'position',[300, 300, 1100, 400]);
for k = 1:length(params)
    NUM_APPS = params(k);

    data_mutants = zeros(NUM_DATA_POINTS, NUM_APPS);
    data_time_ms = zeros(NUM_DATA_POINTS, NUM_APPS);
    data_cost = zeros(NUM_DATA_POINTS, NUM_APPS);
    data_util = zeros(NUM_DATA_POINTS, NUM_APPS);
    
    series_data = zeros(3, NUM_APPS);
    
    for i = 1:NUM_DATA_POINTS
        data = readtable(sprintf('stats_g%d_n%d/exp_%d.csv', DEFAULT_GRANULARITY, NUM_APPS, i - 1));
        data_mutants(i, : ) = data{1, : };
        data_time_ms(i, : ) = data{2, : } * 1E3;
        data_cost(i, : ) = data{3, : };
        data_util(i, : ) = data{4, : };
    end
    
    for i = 1:NUM_APPS
        series_data(1, i) = median(data_time_ms(:, i ));
        series_data(2, i) = median(data_cost(:, i ));
        series_data(3, i) = median(data_util(:, i ));
    end

    time_wc(: , k) = max(data_time_ms, [], 2);
    time_bc(: , k) = min(data_time_ms, [], 2);
    
    % boxplot(data_time_ms);
    subplot(3, 1, 1);
    plot(series_data(1, : ), '-x');
    hold on;

    subplot(3, 1, 2);
    plot(series_data(2, : ), '-x');
    hold on;

    subplot(3, 1, 3);
    plot(series_data(3, : ), '-x');
    hold on;
end

subplot(3,1,1);
ylim([0 10]);
xlabel('Online sequence #');
ylabel('Allocation Time (ms)');
legend(cellstr(num2str(params', 'N=%-d')));
set(gca, 'FontSize', 16);
grid on;

subplot(3,1,2);
% ylim([0 10]);
xlabel('Online sequence #');
ylabel('Reallocation Cost');
legend(cellstr(num2str(params', 'N=%-d')));
set(gca, 'FontSize', 16);
grid on;

subplot(3,1,3);
% ylim([0 10]);
xlabel('Online sequence #');
ylabel('Utilization');
legend(cellstr(num2str(params', 'N=%-d')));
set(gca, 'FontSize', 16);
grid on;

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