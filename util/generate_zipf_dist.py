#!/usr/bin/python3

import sys
import numpy as np

a = float(sys.argv[1]) if len(sys.argv) > 1 else 2
n = int(sys.argv[2]) if len(sys.argv) > 2 else 10000

samples = np.random.zipf(a, n)

frequency = np.bincount(samples)[1:]

filename = "zipf_dist_a_%.2f_n_%d.csv" % (a, n)

with open(filename, "w") as out:
    data = [ str(x) for x in frequency ]
    out.write("\n".join(data))
    out.close()

print("wrote %d data points to %s." % (len(frequency), filename))