#!/usr/bin/python3

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

data = np.array(pd.read_csv('ping_stats.csv').values, dtype=np.float64)
data /= 1000

plt.figure()
plt.hist(data, bins=100, density=True, cumulative=True, histtype='step', label='CDF', color='blue')
plt.xlim(0, 20)
plt.ylabel("CDF")
plt.xlabel("Latency (us)")
plt.grid()
plt.savefig("ping_cdf.png")