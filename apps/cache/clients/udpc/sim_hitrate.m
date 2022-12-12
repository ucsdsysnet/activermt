clear;
clc;

KEYSPACE = 65536;
BLOCKSIZE = 8192;
NUM_REQS = 1000000;

dist_raw = csvread('zipf_dist_a_1.90_n_100000.csv');

distsize = sum(dist_raw(1:KEYSPACE));

dist = zeros(1, distsize);
idx = 1;
for i = 1:KEYSPACE
    for j = 1:dist_raw(i)
        dist(idx) = i;
        idx = idx + 1;
    end
end

num_blocks = [1 2 4 8];
hitrates = zeros(size(num_blocks));

for i = 1:length(num_blocks)
    num_keys = num_blocks(i) * BLOCKSIZE;
    reqs = randsample(dist, NUM_REQS, true);
    hitrates(i) = sum(reqs <= num_keys) / NUM_REQS;
end