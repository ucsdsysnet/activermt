#!/usr/bin/python3

import sys
import numpy as np

def compute_hitrate(dist, memsize, key_max=65535, num_samples = 100000):
    samples = np.zeros(num_samples)
    for i in range(0, num_samples):
        key = key_max + 1
        while key >= key_max:
            key = np.random.choice(dist)
        samples[i] = key
    limit = np.full(num_samples, memsize)
    hits = np.less_equal(samples, limit)
    hitrate = np.sum(hits) / num_samples
    return hitrate

a = float(sys.argv[1]) if len(sys.argv) > 1 else 2
n = int(sys.argv[2]) if len(sys.argv) > 2 else 10000
m = int(sys.argv[3]) if len(sys.argv) > 3 else 8192

key_max = 65535

samples = np.random.zipf(a, n)

dist_max = samples.max()

print("Max dist value:", dist_max)

if dist_max > key_max:
    hitrate = compute_hitrate(samples, m, key_max=key_max)
    print("Estimated Hitrate:", hitrate)
else:
    print("Maximum dist value less than range!")

# frequency = np.bincount(samples)[1:]

filename = "zipf_dist_a_%.1f_n_%d.csv" % (a, n)

with open(filename, "w") as out:
    data = [ str(x) for x in samples ]
    out.write("\n".join(data))
    out.close()

print("wrote %d data points to %s." % (len(samples), filename))