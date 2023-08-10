clear;
clc;

data_baseline = readtable('igpipe_min_latency.csv');
data_memread = readtable('igpipe_memread_latency.csv');
data_memsync = readtable('igpipe_memsync_latency.csv');
data_memsync_ig = readtable('igpipe_memsync_igonly.csv');
% data_hop_ingress = readtable('igpipe_hop_latency_igonly.csv');
% data_hop_complete = readtable('igpipe_hop_latency_igeg.csv');

figure;
cdfplot(data_baseline{ : , 4});
hold on;
cdfplot(data_memread{ : , 5});
hold on;
cdfplot(data_memsync{ : , 5});
hold on;
cdfplot(data_memsync_ig{ : , 5});
% cdfplot(data_hop_ingress{ : , 5});
% hold on;
% cdfplot(data_hop_complete{ : , 5});

xlabel('Latency (ns)');
legend('gress baseline', 'gress memread', 'memsync', 'memsync (ingress only)');
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, 'processing_latency_comparison.png');