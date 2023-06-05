clear;
clc;

NUM_EXP = 100;
NUM_APPS = 20;

X = 1:NUM_APPS;
Y = zeros(NUM_EXP, NUM_APPS);

for i = 1:NUM_EXP
    filename = sprintf('results_arrivals_n100/arrivals_exp_%d.csv', i - 1);
    data = csvread(filename);
    Y(i, : ) = data( : , 2);
end

Y = Y / 1E6;

figure;
boxplot(Y);
xlabel('Seq #');
ylabel('Time (ms)');
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'arrivals_time.png');