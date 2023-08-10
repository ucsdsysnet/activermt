%{
[tools] netproxy, tofino-model, http-server, http-client
[env] N servers connected to the emulator; 1 client sending http requests
that are load balanced by the active program running on the emulator.
[params] 1000 requests sent by the client to the servers. 
[metric] for each server: the number of requests served per second is
recorded, the variance across the duration of the experiment is computed;
the variance across all servers are reported as quantiles.
%}

clear;
clc

data = csvread('server-dataset.csv');

X = data( : , 1);

server_load = data( : , 2:end);

MEAN_LOAD = mean(reshape(server_load, [1 numel(server_load)]));
NUM_SERVERS = size(server_load, 2);

var_load = var(server_load);

figure
boxplot(var_load', 'Notch', 'on', 'Labels', {num2str(NUM_SERVERS, 'N=%d')});
title(sprintf('Load variance across %d servers', NUM_SERVERS));
xlabel('Number of servers');
ylabel(sprintf('Variance (w/ %d avg #connections)', round(MEAN_LOAD)));
ylim([0 1]);
set(gca, 'FontSize', 16);
grid on

figure
plot(X, server_load, '-x');
title(sprintf('Balanced load across %d servers', NUM_SERVERS));
xlabel('Time (seconds)');
ylabel('# connections');
legend(cellstr(num2str((1:NUM_SERVERS)', 'Server %-d')));
ylim([0 10]);
set(gca, 'FontSize', 16);
grid on