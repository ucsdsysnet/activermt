% combined analysis for cache and load balancing

clear;
clc

data_lb = readtable('lb/data/gc_dataplane.csv');
data_lb = data_lb{3, : }';

data_cache = zeros(3, 1);
for i = 0:2
    data = csvread( sprintf('cache/exp_v3/responses_%d.csv', i));
    data = data(1:65520, : );
    data = data( : , 3);
    data_cache(i + 1) = mean(data) / 1000;
end

worst_pcc = max(data_lb);
worst_response = max(data_cache);

pcc = data_lb * 100 ./ worst_pcc;
response = data_cache * 100 ./ worst_response;
response = flip(response);

figure
bar(1:3, [pcc, response]);
grid on
set(gca, 'xtick', 1:3, 'xticklabel', {'1+3', '2+2', '3+1'});
xlabel('Resource Allocation (LB + Cache)');
ylabel('Performance (% of worst)');
title('Performance of co-existing applications');