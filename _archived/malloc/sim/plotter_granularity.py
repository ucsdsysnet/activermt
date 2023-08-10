#!/usr/bin/python3

import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.ticker import StrMethodFormatter
import numpy as np
import pandas as pd
from glob import glob

import os
import sys
import json

if len(sys.argv) < 3:
    print("Usage: {} <data_dir> <config_path>".format(sys.argv[0]))
    sys.exit(1)

data_dir = sys.argv[1]
plot_dir = os.path.join(os.getcwd(), "plots", os.path.basename(data_dir))
config_path = sys.argv[2]

if not os.path.exists(plot_dir):
    os.makedirs(plot_dir)

num_epochs = 0
num_repeats = 0
num_schemes = 0
wl = None

schemes = []
with open(config_path, 'r') as f:
    config = json.load(f)
    num_epochs = config['epochs']
    num_repeats = config['repeats']
    wl = config['workload']
    for scheme in config['schemes']:
        scheme_id = scheme['fit'] if scheme['obj'] == 'fit' else scheme['obj']
        scheme_id += "-{}".format(scheme['constr'])
        if 'granularity' in scheme:
            granularity = int(94208 * 4 / scheme['granularity'])
            scheme_id = "{}B".format(granularity)
        schemes.append(scheme_id)
    f.close()

assert len(schemes) > 0

num_schemes = len(schemes)

data_allocation_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
data_apply_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)

for r in range(num_repeats):
    for s in range(num_schemes):
        for e in range(num_epochs):
            summary_path = os.path.join(data_dir, str(r), str(s), str(e), "summary.csv")
            if os.path.exists(summary_path):
                summary = pd.read_csv(summary_path)
                if summary['time_compute'].values[0] > 0:
                    data_allocation_time[r][s][e] = summary['time_compute'].values[0] * 1000
                    data_apply_time[r][s][e] = summary['time_apply'].values[0] * 1000
                else:
                    data_allocation_time[r][s][e] = np.nan
                    data_apply_time[r][s][e] = np.nan
            else:
                data_allocation_time[r][s][e] = np.nan
                data_apply_time[r][s][e] = np.nan

data_total_time = data_allocation_time + data_apply_time

plt.figure()
plt.title("Allocation Time ({})".format(wl))
plt.xlabel("Epoch")
plt.ylabel("Time (ms)")
plt.grid()
for s in range(num_schemes):
    Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            # Y[b][a] = data_allocation_time[a][s][b]
            Y[b][a] = data_total_time[a][s][b]
    Y = np.mean(Y, axis=1)
    plt.plot(Y)
    scheme_dirname = os.path.join("matlab", "granularity", wl, schemes[s])
    if not os.path.exists(scheme_dirname):
        os.makedirs(scheme_dirname)
    path_data = os.path.join(scheme_dirname, "allocation_time.csv")
    np.savetxt(path_data, Y, delimiter=",")
plt.legend(schemes)
plt.savefig(os.path.join(plot_dir, "allocation_time.png"))