clear;
clc;

NUM_REPEATS = 10;
DURATION = 100;
DATADIR = 'allocation';

params_colors = {'b', 'r'};

fid_total = zeros(DURATION, NUM_REPEATS);
fid_snapshots = zeros(DURATION, NUM_REPEATS);
timings_total = zeros(DURATION, NUM_REPEATS);
timings_snapshots = zeros(DURATION, NUM_REPEATS);

T1 = [];
T2 = [];

for k = 1:NUM_REPEATS
    data_client_apps = readtable(sprintf('evals/%s/%d/results_times_apps.csv', DATADIR, k - 1));
    data_client_ticks = readtable(sprintf('evals/%s/%d/results_allocation_times.csv', DATADIR, k - 1));
    data_controller = readtable(sprintf('evals/%s/%d/results_controller.csv', DATADIR, k - 1));
    fid_a = data_client_apps{ : , 1};
    fid_b = data_controller{ : , 1};
    allocation_time_ms = data_controller{ : , 2};
    snapshot_time_ms = data_client_apps{ : , 3} / 1E6;
%     allocation_time_ms = data_client_ticks{ : , 1} / 1E6;
%     snapshot_time_ms = data_client_ticks{ : , 2} / 1E6;

%     allocation_time_ms = allocation_time_ms ./ data_client_ticks{ : , 3};
%     snapshot_time_ms = snapshot_time_ms ./ data_client_ticks{ : , 3};

    timings_total( fid_a , k) = allocation_time_ms;
    timings_snapshots( fid_b , k) = snapshot_time_ms;
    fid_total(fid_a, k) = fid_a;
    fid_snapshots(fid_b, k) = fid_b;

    T1 = [T1; allocation_time_ms];
    T2 = [T2; snapshot_time_ms];
    
%     time_ms = [snapshot_time_ms, data_controller{ : , 2}]';
end

figure;

% area(data_controller{ : , 1}, data_controller{ : , 2});
% hold on;
% area(FID, snapshot_time_ms);
% plot(FID, allocation_time_ms, '-square');
% % plot(data_controller{ : , 1}, data_controller{ : , 2}, '-square');
% hold on;
% plot(FID, snapshot_time_ms, '-x');

timings_total(fid_total == 0) = NaN;
timings_snapshots(fid_snapshots == 0) = NaN;

avg_allocation = nanmean(timings_total, 2);
lb_a = min(timings_total, [], 2);
ub_a = max(timings_total, [], 2);
neg_a = avg_allocation - lb_a;
pos_a = ub_a - avg_allocation;

avg_snapshots = nanmean(timings_snapshots, 2);
lb_s = min(timings_snapshots, [], 2);
ub_s = max(timings_snapshots, [], 2);
neg_s = avg_snapshots - lb_s;
pos_s = ub_s - avg_snapshots;

max_fid = max(fid_total, [], "all");

a = area(1:max_fid, avg_allocation(1:max_fid), 'FaceColor', params_colors{1}, 'EdgeColor', 'none');
a.FaceAlpha = 0.4;
hold on;
b = area(1:max_fid, avg_snapshots(1:max_fid), 'FaceColor', params_colors{2}, 'EdgeColor', 'none');
b.FaceAlpha = 0.4;
hold on;

errorbar(1:DURATION, avg_allocation, neg_a, pos_a, 'LineWidth', 1.5, 'Color', params_colors{1});
hold on;
errorbar(1:DURATION, avg_snapshots, neg_s, pos_s, 'LineWidth', 1.5, 'Color', params_colors{2});

% plot(avg_allocation, '-square', 'LineWidth', 2);
% hold on;
% plot(avg_snapshots, '-square', 'LineWidth', 1.5);

ylabel('Total Time (ms)');
xlabel('App #');

% cdfplot(T1);
% hold on;
% cdfplot(T2);
% xlabel('Time (ms)');

lgd = legend('Allocation', 'Snapshot');
lgd.Location = 'northwest';
lgd.FontSize = 12;
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, 'allocation_time_duration_based.png');