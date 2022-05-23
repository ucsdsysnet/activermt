% analysis script for responses

clear;
clc

NUM_STAGES = 3;
MEM_PER_STAGE = 8190;

styles = {'-', ':', '--', '-.'};
averages = zeros(NUM_STAGES, NUM_STAGES);

for i = 1:NUM_STAGES
    data = csvread( sprintf('exp_v3/responses_%d.csv', i) );
    for j = 1:NUM_STAGES
        demand = MEM_PER_STAGE * j;
        chunk = data(1:demand, : );
        rtimes = chunk( : , 3);
        averages(i, j) = mean(rtimes) / 1000;
    end
end

figure
bar([1:NUM_STAGES], averages);
ylabel('Response Time (us)');
xlabel('#Stages');
grid on