clear;
clc

NUM_PROGS = 10;
NUM_STAGES = 20;

dist_prog = zeros(NUM_PROGS, 1);
for i = 1:NUM_PROGS
    dist_prog = nchoosek(NUM_STAGES + NUM_PROGS - i + NUM_PROGS, NUM_PROGS) / (NUM_STAGES^NUM_PROGS);
end

figure
plot(1:NUM_PROGS, dist_prog);