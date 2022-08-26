clear;
clc

data = csvread('exp.csv');

figure
yyaxis left
plot(data( : , 1));
hold on
plot(data( : , 2));
ylabel('Latency (sec)');
yyaxis right
plot(data( : , 6));
ylabel('# Trials');
xlabel('#app');
grid on
legend('allocation time', 'overall time');
set(gca, 'FontSize', 16);
title('Allocation Sequence');