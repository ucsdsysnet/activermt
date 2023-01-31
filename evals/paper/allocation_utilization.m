clear;
clc;

BASE_PATH = '../../malloc/evals/recirculated';
OUTPUT_PATH = 'figures/overheads';

GRANULARITY = 256;
NUM_DATA_POINTS = 100;
NUM_APPS = 64;
PARAM_FIT = 'wf';
PARAM_WORKLOAD = 'cache';

NUM_STAGES_NETVRM = 8;
NUM_STAGES_P4 = 11;
NUM_STAGES_ACTIVE = 10;
NUM_STAGES_TOFINO = 12;

NUM_BLOCKS_PER_STAGE_NETVRM = 33;
NUM_BLOCKS_PER_STAGE_P4 = 48;
NUM_BLOCKS_PER_STAGE_ACTIVE = 48;
NUM_BLOCKS_PER_STAGE_TOFINO = 48;

TOFINO_MAX = NUM_STAGES_TOFINO * NUM_BLOCKS_PER_STAGE_TOFINO;
ACTIVE_MAX = NUM_STAGES_ACTIVE * NUM_BLOCKS_PER_STAGE_ACTIVE;
P4_MAX = NUM_STAGES_P4 * NUM_BLOCKS_PER_STAGE_P4;
NETVRM_MAX = NUM_STAGES_NETVRM * NUM_BLOCKS_PER_STAGE_NETVRM;

exp_id = randsample(NUM_DATA_POINTS, 1) - 1;

data_utilization = readtable(sprintf( ...
    '%s/stats_g%d_n%d_%s_%s_recirculated/%d/utilization.csv', ...
    BASE_PATH, ...
    GRANULARITY, ...
    NUM_APPS, ...
    PARAM_WORKLOAD, ...
    PARAM_FIT, ...
    exp_id ...
));
data_utilization = table2array(data_utilization) * (ACTIVE_MAX / TOFINO_MAX);

figure;
plot(data_utilization, '-square');
xlabel('App #');
ylabel('Utilization');
hline = refline(0, TOFINO_MAX / TOFINO_MAX);
hline.Color = 'r';
hline.LineStyle = '--';
hline.LineWidth = 2.0;
hline = refline(0, ACTIVE_MAX / TOFINO_MAX);
hline.Color = 'k';
hline.LineStyle = '--';
hline.LineWidth = 2.0;
hline = refline(0, P4_MAX / TOFINO_MAX);
hline.Color = 'g';
hline.LineStyle = '--';
hline.LineWidth = 2.0;
hline = refline(0, NETVRM_MAX / TOFINO_MAX);
hline.Color = 'c';
hline.LineStyle = '--';
hline.LineWidth = 2.0;
lgd = legend('Active Cache', 'Tofino Maximum', 'ActiveRMT Maximum', 'P4 Maximum', 'NetVRM Maximum');
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;
saveas(gcf, sprintf('%s/utilization_d%d_n%d_%s_comparison.png', OUTPUT_PATH, GRANULARITY, NUM_APPS, PARAM_WORKLOAD));