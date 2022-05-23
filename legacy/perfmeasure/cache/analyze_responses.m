% analysis script for responses

clear;
clc

NUM_STAGES = 8;
MEM_PER_STAGE = 8190;

styles = {'-', ':', '--', '-.'};
averages = zeros(NUM_STAGES + 1, 1);

figure

for i = 0:NUM_STAGES
    data = csvread( sprintf('responses_%d.csv', i));
    data = data(1:65520, : );
    rtimes = data( : , 3);
    h = cdfplot(rtimes / 1000);
    hold on
    set(h(1), 'LineStyle', styles{mod(i, 4) + 1});
    averages(i + 1) = mean(rtimes) / 1000;
end

title('Reponse Time / #Stages (N)');
xlabel('Response Time (us)');
xlim([0, 100]);
legend(cellstr(num2str([0:NUM_STAGES]','N=%-d')));

figure
bar([0:NUM_STAGES], averages);
ylabel('Response Time (us)');
xlabel('#Stages');
grid on

figure
for i = 1:NUM_STAGES
    rt = rtimes( (i - 1) * MEM_PER_STAGE + 1 : i * MEM_PER_STAGE );
    cdfplot(rt / 1000);
    hold on
end
title('Read time variability / #stages');
xlabel('Response Time (us)');
xlim([0, 100]);
legend(cellstr(num2str([1:NUM_STAGES]','N=%-d')));