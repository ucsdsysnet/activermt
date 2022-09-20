clear;
clc;

data = csvread('cache_samples_w_reallocation.csv');
data_alt = csvread('cache_samples_other_app.csv');

ts = data( : , 1);
hitrate = data( : , 2);

exp_start = min(ts);
X = ts - exp_start;

ts_alt = data_alt( : , 1);
hr_alt = data_alt( : , 2);

X_alt = ts_alt - exp_start;

figure;
plot(X, hitrate, '-square');
hold on;
plot(X_alt, hr_alt, '-x');
xlabel('Time (sec)');
ylabel('Cache hit-rate');
ylim([0 1]);
set(gca, 'FontSize', 16);
legend('Old instance', 'Incoming instance');
grid on;

saveas(gcf, 'reallocation_cache.png');