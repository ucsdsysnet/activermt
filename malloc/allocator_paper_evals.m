clear;
clc;

NUM_DATA_POINTS = 100;

param_fit = ["ff", "bf"];
param_metric = "relocations";
param_workload = ["cache", "cheetahlb", "cms", "random"];

num_fits = length(param_fit);
num_workloads = length(param_workload);

data_cost = zeros(2, num_workloads);
data_utilization = zeros(2, num_workloads);
data_numapps = zeros(2, num_workloads);
data_time = zeros(2, num_workloads, NUM_DATA_POINTS);

for i = 1:num_workloads
    for j = 1:num_fits
        metric = param_metric;
        if param_fit(j) == "ff"
            metric = "sat";
        end
        datafile = sprintf("allocation_%s_%s_%s.csv", param_workload(i), param_fit(j), metric);
        if isfile(datafile)
    
            data = csvread(datafile);
    
            cost = data( : , 1);
            utilization = data( : , 2);
            utility = data( : , 3);
            allocTime = data( : , 4);
    
            numAllocations = data( : , 5);
            numDepartures = data( : , 6);
            
            data_cost(j, i) = median(cost(:));
            data_utilization(j, i) = median(utilization(:));
            data_numapps(j, i) = median(numAllocations(:));
            data_time(j, i, :) = allocTime(:) * 1E6;
        end
    end
end

figure;
set(gcf,'position',[300, 300, 1100, 400]);
subplot(1, 2, 1);
boxplot(reshape(data_time(1, :, :), [num_workloads, NUM_DATA_POINTS])');
title("Strawman");
ylabel("Allocation Time (us)");
ylim([300 1200]);
xticklabels(param_workload);
set(gca, 'FontSize', 16);
grid on;
subplot(1, 2, 2);
boxplot(reshape(data_time(2, :, :), [num_workloads, NUM_DATA_POINTS])');
title("Cost-Based");
ylabel("Allocation Time (us)");
ylim([300 1200]);
xticklabels(param_workload);
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'paper_allocation_time.png');

% cost, util, #apps.
figure;
set(gcf,'position',[300, 300, 1100, 400]);
subplot(1, 2, 1);
yyaxis left;
plot(data_cost(1, : ), '--square', 'MarkerSize', 10);
hold on;
plot(data_cost(2, : ), '-x', 'MarkerSize', 10);
hold on;
ylabel('# Reallocations');
ylim([0, max(data_cost(1, : ) + 10)]);
yyaxis right;
plot(data_numapps(1, : ), '--square', 'MarkerSize', 10);
hold on;
plot(data_numapps(2, : ), '-x', 'MarkerSize', 10);
ylabel('# Apps');
ylim([0, max(data_numapps(1, : ) + 5)]);
xticks(1:num_workloads);
xticklabels(param_workload);
lgd = legend('Strawman', 'Cost-Based');
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
subplot(1, 2, 2);
yyaxis left;
plot(data_utilization(1, : ), '--square', 'MarkerSize', 10);
hold on;
plot(data_utilization(2, : ), '-x', 'MarkerSize', 10);
hold on;
ylabel('Utilization');
ylim([0 1]);
yyaxis right;
plot(data_numapps(1, : ), '--square', 'MarkerSize', 10);
hold on;
plot(data_numapps(2, : ), '-x', 'MarkerSize', 10);
ylabel('# Apps');
ylim([0, max(data_numapps(1, : ) + 5)]);
xticks(1:num_workloads);
xticklabels(param_workload);
lgd = legend('Strawman', 'Cost-Based');
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'paper_allocation_cost_util_numapps.png');