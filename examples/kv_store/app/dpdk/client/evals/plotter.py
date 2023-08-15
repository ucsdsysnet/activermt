#!/usr/bin/python3

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

NUM_APPS = 4
ALPHA = 0.01

hit_rates = [ None for _ in range(NUM_APPS) ]

time_ref = 1E6

for i in range(NUM_APPS):
    data_path = "cache_rx_stats_{}.csv".format(i + 1)
    data = pd.read_csv(data_path, header=None, names=["time", "rx_hits", "rx_total"])
    T = np.array(data["time"].values, dtype=np.float32) / 1E3
    H = np.array(data["rx_hits"].values) / np.array(data["rx_total"].values)
    hit_rates[i] = (T, H)
    time_ref = min(time_ref, np.min(T))

plt.figure()
for i in range(NUM_APPS):
    T, H = hit_rates[i]
    Y = np.zeros(len(T))
    Y[0] = H[0]
    for j in range(1, len(T)):
        Y[j] = ALPHA * H[j] + (1 - ALPHA) * Y[j - 1]
    plt.plot(T - time_ref, Y, label="App {}".format(i + 1))
plt.xlim(0, 25)
plt.xlabel("Time (sec)")
plt.ylabel("Hit rate")
plt.legend(loc="lower right")
plt.grid()
plt.savefig("hit_rates_concurrent.png")