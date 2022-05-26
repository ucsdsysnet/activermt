%{
[tools] netproxy, tofino-model, http-server, http-client
[env] a client container and a server container connected via an emulated
switch (and using a tun netfilter); netfilter implemented cookie corruption
- from a random packet onwards cookies in all subsequent packets are
corrupted; packets with corrupted cookies are forwarded to a unknown server
not serving and http requests; connections are broken when packets are
forwarded to an unknown location.
[params] client sent a total of 1000 requests with a request timeout of
100ms. 
[metric] fraction of requests that fail due to broken connections; rate of
requests per second taking into account broken connections.
%}

clear;
clc

num_threads = 1;

data_corr = csvread('stats_corruption.csv');
data_reg = csvread('stats_normal.csv');
violations_corr = data_corr( : , 3) * 100 ./ ( data_corr( : , 2) + data_corr( : , 3) );
req_rates_corr = data_corr( : , 4);
violations_reg = data_reg( : , 3) * 100 ./ ( data_reg( : , 2) + data_reg( : , 3) );
req_rates_reg = data_reg( : , 4);

figure
subplot(2,1,1);
cdfplot(violations_reg);
hold on
cdfplot(violations_corr);
title('PCC violations w/ cookie corruption');
xlabel('PCC violations (%)');
legend('normal', 'w/ corruption');
set(gca, 'FontSize', 16);
grid on
subplot(2,1,2);
cdfplot(req_rates_reg);
hold on
cdfplot(req_rates_corr);
title('Request rates w/ cookie corruption');
xlabel('Requests/sec');
legend('normal', 'w/ corruption');
set(gca, 'FontSize', 16);
grid on