clear;
clc;

NUM_STAGES = 20;
PARAM_GRANULARITY = 368;
PARAM_DURATION = 100;
PARAM_FIT = 'wf';
PARAM_NUMREPS = 10;
PARAM_WL = 'random';
PARAM_ARRIVAL_RATE = 2;

params_constraints = {'lc', 'mc'};

param_markers = {'--square', '-x'};
param_colors = {'r', 'b', 'g', 'k'};

labels_constraints = {'least-constr', 'most-constr'};

figure;
for i = 1:length(params_constraints)
    wl = PARAM_WL;
    constr = params_constraints{i};

    utilization = zeros(PARAM_DURATION, PARAM_NUMREPS);

    for j = 1:PARAM_NUMREPS
        exp_id = j - 1;
        data_utilization = readtable(sprintf( ...
            'timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/utilization.csv', ...
            PARAM_GRANULARITY, ...
            PARAM_DURATION, ...
            wl, ...
            PARAM_FIT, ...
            constr, ...
            PARAM_ARRIVAL_RATE, ...
            exp_id ...
        ));
        utilization( : , j) = data_utilization{ : , 1};
    end

    util_avg = mean(utilization, 2);
    util_lb = min(utilization, [], 2);
    util_ub = max(utilization, [], 2);
    err_neg = util_avg - util_lb;
    err_pos = util_ub - util_avg;

    errorbar(1:PARAM_DURATION, util_avg, err_neg, err_pos);
    hold on;
    ylim([0 1]);
end

ylabel('Utilization');
xlabel('Time (ticks)');
legend(labels_constraints);
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, sprintf('utilization_sim_random_%d_ticks.png', PARAM_DURATION));

figure;
for i = 1:length(params_constraints)
    wl = PARAM_WL;
    constr = params_constraints{i};

    occupancy = zeros(PARAM_DURATION, PARAM_NUMREPS);

    for j = 1:PARAM_NUMREPS
        exp_id = j - 1;
        data_occupancy = readtable(sprintf( ...
            'timesimulation_stats_g%d_t%d_%s_%s_%s_a%d/%d/occupancy.csv', ...
            PARAM_GRANULARITY, ...
            PARAM_DURATION, ...
            wl, ...
            PARAM_FIT, ...
            constr, ...
            PARAM_ARRIVAL_RATE, ...
            exp_id ...
        ));
        occupancy( : , j) = data_occupancy{ : , 1};
    end

    occ_avg = mean(occupancy, 2);
    occ_lb = min(occupancy, [], 2);
    occ_ub = max(occupancy, [], 2);
    err_neg = occ_avg - occ_lb;
    err_pos = occ_ub - occ_avg;

    errorbar(1:PARAM_DURATION, occ_avg, err_neg, err_pos);
    hold on;
end

ylabel('Occupancy (# apps)');
xlabel('Time (ticks)');
legend(labels_constraints);
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, sprintf('occupancy_sim_random_%d_ticks.png', PARAM_DURATION));