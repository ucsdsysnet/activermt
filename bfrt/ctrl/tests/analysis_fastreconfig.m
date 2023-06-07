clear;
clc;

data_coldinit = csvread('results_asic_coldinit.csv');
data_fastreconfig = csvread('results_asic_fastreconfig.csv');

figure;
cdfplot(data_coldinit);
hold on;
cdfplot(data_fastreconfig);
xlim([0,max([data_fastreconfig; data_coldinit])]);
xlabel('Configuration time (ms)');
legend('Cold Init', 'Fast Reconfig');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'fastreconfig_python.png');