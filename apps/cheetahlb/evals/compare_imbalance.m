clear;
clc

data = csvread('server-dataset.csv');

X = data( : , 1);

server_load = data( : , 2:end);
avg_load = mean(data( :, 2:end), 2);

MAX_LOAD = max(reshape(server_load, [1 numel(server_load)]));
NUM_SERVERS = size(server_load, 2);

imbalance = server_load ./ avg_load;
pct_load = (server_load * 100) / MAX_LOAD;

var_load = var(pct_load')';

plot(X, var_load, '-x');
title(sprintf('Load variance across %d servers', NUM_SERVERS));
xlabel('Time (seconds)');
ylabel('Variance across % load');
ylim([0 100]);
set(gca, 'FontSize', 16);
grid on