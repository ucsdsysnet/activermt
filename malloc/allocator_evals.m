clear;
clc

NUM_DATA_POINTS = 100;

param_fit = ["bf", "wf"];
param_metric = ["relocations", "utility", "utilization"];
param_seq = ["cache", "cheetahlb", "cms", "random"];
% param_seq = ["cache", "cheetahlb"];

Y_cost = zeros(NUM_DATA_POINTS, length(param_seq));
Y_utilization = zeros(NUM_DATA_POINTS, length(param_seq));
Y_numallocs = zeros(NUM_DATA_POINTS, length(param_seq));
Y_time = zeros(NUM_DATA_POINTS, length(param_seq));
for i = 1:length(param_seq)
    datafile = sprintf("allocation_%s_ff_sat.csv", param_seq(i));
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
    end
end

numcols = 2;
numrows = 2;
figure
set(gcf, 'Position', get(0, 'Screensize'));

subplot(numrows, numcols, 1);
boxplot(Y_time * 1E6);
ylabel("Allocation Time (us)");
xticklabels(param_seq);
set(gca, 'FontSize', 16);
grid on

subplot(numrows, numcols, 2);
boxplot(Y_utilization);
ylabel("Utilization");
xticklabels(param_seq);
set(gca, 'FontSize', 16);
grid on

subplot(numrows, numcols, 3);
boxplot(Y_numallocs);
ylabel("Number of allocations");
xticklabels(param_seq);
set(gca, 'FontSize', 16);
grid on

subplot(numrows, numcols, 4);
boxplot(Y_cost);
ylabel("Cost");
xticklabels(param_seq);
set(gca, 'FontSize', 16);
grid on

% for k = 1:length(param_metric)
%     for j = 1:length(param_fit)
%         for i = 1:length(param_seq)
%             datafile = sprintf("allocation_%s_%s_%s.csv", param_seq(i), param_fit(j), param_metric(k));
%             if isfile(datafile)
% 
%                 data = readtable(datafile);
% 
%                 cost = data( : , 1);
%                 utilization = data( : , 2);
%                 utility = data( : , 3);
%                 allocTime = data( : , 4);
% 
%                 numAllocations = data( : , 5);
%                 numDepartures = data( : , 6);
% 
% 
%             end
%         end
%     end
% end