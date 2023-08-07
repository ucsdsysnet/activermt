#!/usr/bin/python3

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import os
import sys
import json

if len(sys.argv) < 3:
    print("Usage: {} <config_1> <config_2> [num_epochs=100]".format(sys.argv[0]))
    sys.exit(1)

config_1 = sys.argv[1]
config_2 = sys.argv[2]

config_path_1 = "config/config_{}.json".format(config_1)

data_dir_1 = "data/results_config_{}".format(config_1)
data_dir_2 = "data/results_config_{}".format(config_2)

print("Loading data from {} and {}".format(data_dir_1, data_dir_2))

plot_dir = "plots/comparison_{}_{}".format(config_1, config_2)
if not os.path.exists(plot_dir):
    os.makedirs(plot_dir)

num_epochs = 100
num_repeats = 0
scheme_id = 0
wl = None

if len(sys.argv) > 3:
    num_epochs = int(sys.argv[3])

with open(config_path_1, 'r') as f:
    config = json.load(f)
    num_repeats = config['repeats']
    wl = config['workload']
    f.close()

data_allocation_time_1 = np.zeros((num_repeats, num_epochs), dtype=np.float32)
data_apply_time_1 = np.zeros((num_repeats, num_epochs), dtype=np.float32)

data_allocation_time_2 = np.zeros((num_repeats, num_epochs), dtype=np.float32)
data_apply_time_2 = np.zeros((num_repeats, num_epochs), dtype=np.float32)

s = scheme_id

for r in range(num_repeats):
    for e in range(num_epochs):
        summary_path = os.path.join(data_dir_1, str(r), str(s), str(e), "summary.csv")
        if os.path.exists(summary_path):
            summary = pd.read_csv(summary_path)
            data_allocation_time_1[r][e] = summary['time_compute'].values[0] * 1000
            data_apply_time_1[r][e] = summary['time_apply'].values[0] * 1000
        else:
            data_allocation_time_1[r][e] = np.nan
            data_apply_time_1[r][e] = np.nan

data_total_time_1 = data_allocation_time_1 + data_apply_time_1

for r in range(num_repeats):
    for e in range(num_epochs):
        summary_path = os.path.join(data_dir_2, str(r), str(s), str(e), "summary.csv")
        if os.path.exists(summary_path):
            summary = pd.read_csv(summary_path)
            data_allocation_time_2[r][e] = summary['time_compute'].values[0] * 1000
            data_apply_time_2[r][e] = summary['time_apply'].values[0] * 1000
        else:
            data_allocation_time_2[r][e] = np.nan
            data_apply_time_2[r][e] = np.nan

data_total_time_2 = data_allocation_time_2 + data_apply_time_2

plt.figure()
plt.title("Allocation Time ({})".format(wl))
plt.xlabel("Epoch")
plt.ylabel("Time (ms)")
plt.grid()
X = np.tile(np.arange(num_epochs), num_repeats)
Y1 = np.zeros((num_epochs, num_repeats), dtype=np.float32)
for a in range(num_repeats):
    Y1[: , a] = data_total_time_1[a][:]
Y1 = np.reshape(Y1, (num_epochs * num_repeats, 1), order='F')
plt.scatter(X, Y1, marker=1)
Y2 = np.zeros((num_epochs, num_repeats), dtype=np.float32)
for a in range(num_repeats):
    Y2[: , a] = data_total_time_2[a][:]
Y2 = np.reshape(Y2, (num_epochs * num_repeats, 1), order='F')
plt.scatter(X, Y2, marker=2)
plt.legend(['{}_1'.format(wl), '{}_2'.format(wl)])
plt.savefig(os.path.join(plot_dir, "allocation_time_scatter.png"))