clear;
clc

data = csvread('server-dataset.csv');

X = data( : , 1);

server_load = data( : , 2:end);

MEAN_LOAD = mean(reshape(server_load, [1 numel(server_load)]));
NUM_SERVERS = size(server_load, 2);

var_load = var(server_load, 1, 2);

figure
plot(X, var_load, '-x');
title(sprintf('Load variance across %d servers', NUM_SERVERS));
xlabel('Time (seconds)');
ylabel(sprintf('Variance (w/ %d avg #connections)', round(MEAN_LOAD)));
ylim([0 1]);
set(gca, 'FontSize', 16);
grid on

figure
plot(X, server_load, '-x');
title(sprintf('Balanced load across %d servers', NUM_SERVERS));
xlabel('Time (seconds)');
ylabel('# connections');
legend(cellstr(num2str([1:NUM_SERVERS]', 'Server %-d')));
ylim([0 10]);
set(gca, 'FontSize', 16);
grid on