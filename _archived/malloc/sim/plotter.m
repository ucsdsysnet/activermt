clear;
clc;

num_repeats = 10;
num_epochs = 100;

schemes = {'ff', 'wf', 'bf', 'realloc'};

num_schemes = length(schemes);

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/utilization.csv',schemes{s}));
    plot(data{: , 1}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Epoch');
ylabel('Utilization');
lgd = legend(schemes);
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/utilization.png');

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/utilization_cdf.csv',schemes{s}));
    plot(data{: , 1}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Utilization (%)');
ylabel('CDF');
lgd = legend(schemes);
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/utilization_cdf.png');

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/reallocated.csv',schemes{s}));
    scatter(1:height(data), data{: , 1}, 10);
    hold on;
end
ylabel('Reallocations (% of elastic)');
xlabel('Epoch');
lgd = legend(schemes);
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/reallocations.png');

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/reallocated_cdf.csv',schemes{s}));
    plot(data{: , 1}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Reallocations (% of elastic)');
ylabel('CDF');
xlim([0 100]);
lgd = legend(schemes);
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/reallocations_cdf.png');

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/fairness.csv',schemes{s}));
    plot(data{: , 1}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Epoch');
ylabel('Fairness');
lgd = legend(schemes);
lgd.Location = 'southwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/fairness.png');

figure;
Y = zeros(num_epochs * num_repeats, num_schemes);
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/fairness_box.csv',schemes{s}));
    Y( : , s) = data{ : , 1};
end
boxplot(Y);
xticklabels(schemes);
ylabel('Fairness');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/fairness_box.png');

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/failures_cum.csv',schemes{s}));
    plot(data{: , 1}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Epoch');
ylabel('Cumulative Failures');
lgd = legend(schemes);
lgd.Location = 'northwest';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/failures_cum.png');

figure;
for s = 1:num_schemes
    data = readtable(sprintf('matlab/%s/failures_cdf.csv',schemes{s}));
    plot(data{: , 1}, 'LineWidth', 1.5);
    hold on;
end
xlabel('Failure Rate (%) / Epoch');
ylabel('CDF');
lgd = legend(schemes);
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'matlab/failures_cdf.png');