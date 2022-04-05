clear;
clc

dist = "web";
linkSpeed = 10;
expTime = 30;

data_completed = csvread(sprintf("data/results_%s_completed_%dG_%dS.csv", dist, linkSpeed, expTime));
data_delayed = csvread(sprintf("data/results_%s_delayed_%dG_%dS.csv", dist, linkSpeed, expTime));

figure
cdfplot(data_completed);
hold on
cdfplot(data_delayed);
hold on
cdfplot([ data_completed; data_delayed ]);

title(sprintf("Traffic=%s / LinkSpeed=%dG", dist, linkSpeed));
xlabel('FCT (us)');
legend('No LRU', 'LRU', 'Combined');
%set(gca, 'FontSize', 24)
set(gca, 'XScale', 'log');
grid on