clear;
clc

NUM_DATA_POINTS = 100;

param_fit = ["bf", "wf"];
param_metric = ["relocations", "utility", "utilization"];
param_workload = ["cache", "cheetahlb", "cms", "random"];

data_cost = zeros(length(param_metric), 1 + length(param_fit), length(param_workload));
data_utilization = zeros(length(param_metric), 1 + length(param_fit), length(param_workload));
data_numapps = zeros(length(param_metric), 1 + length(param_fit), length(param_workload));
data_time = zeros(length(param_metric), 1 + length(param_fit), length(param_workload));

Y_cost = zeros(NUM_DATA_POINTS, length(param_workload));
Y_utilization = zeros(NUM_DATA_POINTS, length(param_workload));
Y_numallocs = zeros(NUM_DATA_POINTS, length(param_workload));
Y_time = zeros(NUM_DATA_POINTS, length(param_workload));
for i = 1:length(param_workload)
    datafile = sprintf("allocation_%s_ff_sat.csv", param_workload(i));
    if isfile(datafile)

        data = csvread(datafile);

        cost = data( : , 1);
        utilization = data( : , 2);
        utility = data( : , 3);
        allocTime = data( : , 4);

        numAllocations = data( : , 5);
        numDepartures = data( : , 6);

        Y_cost( : , i) = cost(:);
        Y_utilization( : , i) = utilization(:);
        Y_numallocs( : , i) = numAllocations(:);
        Y_time( : , i) = allocTime(:);
        
        for j = 1:length(param_metric)
            data_cost(j, 1, i) = median(cost(:));
            data_utilization(j, 1, i) = median(utilization(:));
            data_numapps(j, 1, i) = median(numAllocations(:));
            data_time(j, 1, i) = median(allocTime(:)) * 1E6;
        end
    end
end

numcols = 2;
numrows = 2;
figure
set(gcf, 'Position', get(0, 'Screensize'));

subplot(numrows, numcols, 1);
boxplot(Y_time * 1E6);
ylabel("Allocation Time (us)");
xticklabels(param_workload);
set(gca, 'FontSize', 16);
grid on

subplot(numrows, numcols, 2);
boxplot(Y_utilization);
ylabel("Utilization");
xticklabels(param_workload);
set(gca, 'FontSize', 16);
grid on

subplot(numrows, numcols, 3);
boxplot(Y_numallocs);
ylabel("#Apps");
xticklabels(param_workload);
set(gca, 'FontSize', 16);
grid on

subplot(numrows, numcols, 4);
boxplot(Y_cost);
ylabel("Total #Reallocations");
xticklabels(param_workload);
set(gca, 'FontSize', 16);
grid on

saveas(gcf, 'allocations_ff.png');

for k = 1:length(param_metric)
    for j = 1:length(param_fit)
        for i = 1:length(param_workload)
            datafile = sprintf("allocation_%s_%s_%s.csv", param_workload(i), param_fit(j), param_metric(k));
            if isfile(datafile)

                data = csvread(datafile);

                cost = data( : , 1);
                utilization = data( : , 2);
                utility = data( : , 3);
                allocTime = data( : , 4);

                numAllocations = data( : , 5);
                numDepartures = data( : , 6);
            
                data_cost(k, 1 + j, i) = median(cost(:));
                data_utilization(k, 1 + j, i) = median(utilization(:));
                data_numapps(k, 1 + j, i) = median(numAllocations(:));
                data_time(k, 1 + j, i) = median(allocTime(:)) * 1E6;
            end
        end
    end
end

num_fits = 1 + length(param_fit);
num_workloads = length(param_workload);
for i = 1:length(param_metric)
    disp(param_metric(i));
    figure;
    set(gcf, 'Position', get(0, 'Screensize'));
    
    subplot(2,2,1);
    Y = reshape(data_time(i, :, :), [num_fits, num_workloads]);
    h = bar(Y');
    xticks(1:num_workloads);
    ylabel('Allocation Time (us)');
    xticklabels(cellstr(param_workload));
    legend('first-fit', 'minimum', 'maximum');
    set(gca, 'FontSize', 16);
    grid on;

    subplot(2,2,2);
    Y = reshape(data_numapps(i, :, :), [num_fits, num_workloads]);
    h = bar(Y');
    xticks(1:num_workloads);
    ylabel('#Apps');
    xticklabels(cellstr(param_workload));
    legend('first-fit', 'minimum', 'maximum');
    set(gca, 'FontSize', 16);
    grid on;

    subplot(2,2,3);
    Y = reshape(data_cost(i, :, :), [num_fits, num_workloads]);
    h = bar(Y');
    xticks(1:num_workloads);
    ylabel('Total #Reallocations');
    xticklabels(cellstr(param_workload));
    legend('first-fit', 'minimum', 'maximum');
    set(gca, 'FontSize', 16);
    grid on;

    subplot(2,2,4);
    Y = reshape(data_utilization(i, :, :), [num_fits, num_workloads]);
    h = bar(Y');
    xticks(1:num_workloads);
    ylabel('Utilization');
    xticklabels(cellstr(param_workload));
    legend('first-fit', 'minimum', 'maximum');
    set(gca, 'FontSize', 16);
    grid on;
end