clear;
clc;

PARAM_GRANULARITY = 256;
PARAM_NUMAPPS = 256;
PARAM_EXPID = 0;
NUM_EXPS = 100;

params_numapps = [32 64 128 256 1024];

allocated = zeros(1, length(params_numapps));

figure;

for i = 1:length(params_numapps)
    Y = [];
    for j = 1:NUM_EXPS
        data = readtable(sprintf( ...
            'stats_v1/stats_g%d_n%d/exp_%d.csv', ...
            PARAM_GRANULARITY, ...
            params_numapps(i), ...
            j - 1 ...
        ));
        alloctime = data{2, : } * 1E3;
        alloctime = alloctime(alloctime ~= 0);
        Y = [Y alloctime];
        numapps = sum(data{1, : } > 0);
    end
    allocated(i) = numapps;
    cdfplot(Y);
    hold on;
end

% xlim([0 20]);
xlabel('Allocation Time (ms)');
lgd = legend(cellstr(num2str(allocated', 'N=%-d')));
lgd.Location = 'southeast';
set(gca, 'FontSize', 16);
grid on;

saveas(gcf, sprintf('allocation_time_cdf_g%d.png', PARAM_GRANULARITY));