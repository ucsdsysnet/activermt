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

SKIP_SAVING = False

if len(sys.argv) < 3:
    print("Usage: {} <data_dir> <config_path>".format(sys.argv[0]))
    sys.exit(1)

data_dir = sys.argv[1]
plot_dir = os.path.join(os.getcwd(), "evals/plots", os.path.basename(data_dir))
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
        # scheme_id = scheme['fit'] if scheme['obj'] == 'fit' else scheme['obj']
        scheme_id = "{}".format(scheme['constr'])
        schemes.append(scheme_id)
    f.close()

assert len(schemes) > 0

num_schemes = len(schemes)

# num_repeats = 1

data_enum_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
data_search_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
data_pp_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)

data_allocation_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
data_apply_time = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
data_utilization = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
data_failed = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)

data_allocated = np.zeros((num_repeats, num_schemes), dtype=np.float32)

for r in range(num_repeats):
    for s in range(num_schemes):
        num_allocated = 0
        for e in range(num_epochs):
            summary_path = os.path.join(data_dir, str(r), str(s), str(e), "summary.csv")
            if os.path.exists(summary_path):
                summary = pd.read_csv(summary_path)
                failed = (summary['failures'].values[0] == 1)
                data_failed[r][s][e] = 1 if failed else 0
                # data_enum_time[r][s][e] = summary['time_enum'].values[0] * 1000
                # data_search_time[r][s][e] = summary['time_search'].values[0] * 1000
                # data_pp_time[r][s][e] = summary['time_pp'].values[0] * 1000
                data_allocation_time[r][s][e] = summary['time_compute'].values[0] * 1000
                data_apply_time[r][s][e] = summary['time_apply'].values[0] * 1000
                if not failed:
                    data_utilization[r][s][e] = summary['utilization'].values[0]
                    num_allocated += 1
                else:
                    data_utilization[r][s][e] = np.nan
            else:
                data_enum_time[r][s][e] = np.nan
                data_allocation_time[r][s][e] = np.nan
                data_apply_time[r][s][e] = np.nan
        data_allocated[r][s] = num_allocated

data_total_time = data_allocation_time + data_apply_time

allocated = np.nanmean(data_allocated, axis=0)
print("Workload: {}".format(wl))
for s in range(num_schemes):
    print("{}: {} apps allocated".format(schemes[s], allocated[s]))

for i in range(num_schemes):
    Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            Y[b][a] = data_utilization[a][i][b]
    Y = np.nanmean(Y, axis=1)
    max_util = np.max(Y)
    saturation_point = 0
    for j in range(num_epochs):
        if Y[j] == max_util:
            saturation_point = j
            break
    print("{}: saturation point of {} at epoch {}".format(schemes[i], max_util, saturation_point))

if SKIP_SAVING:
    print("Skipping saving plots")
else:
    # allocation time average.
    plt.figure()
    plt.title("Allocation Time ({})".format(wl))
    plt.xlabel("Epoch")
    plt.ylabel("Time (ms)")
    plt.grid()
    for s in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        F = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            for b in range(num_epochs):
                # Y[b][a] = data_allocation_time[a][s][b]
                Y[b][a] = data_total_time[a][s][b]
                F[b][a] = data_failed[a][s][b]
        # Y = np.mean(Y, axis=1)
        Y = np.nanmean(Y, axis=1)
        F = np.nanmean(F, axis=1)
        plt.plot(Y)
        # plt.scatter(np.arange(num_epochs), np.multiply(Y, F), s=10, marker='x', color='red')
        scheme_dirname = os.path.join("matlab", "granularity", wl, schemes[s])
        if not os.path.exists(scheme_dirname):
            os.makedirs(scheme_dirname)
        path_data = os.path.join(scheme_dirname, "allocation_time.csv")
        np.savetxt(path_data, Y, delimiter=",")
    plt.legend(schemes)
    plt.savefig(os.path.join(plot_dir, "allocation_time.png"))

    # allocation time scatter.
    plt.figure()
    plt.title("Allocation Time ({})".format(wl))
    plt.xlabel("Epoch")
    plt.ylabel("Time (ms)")
    plt.grid()
    for s in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            Y[: , a] = data_total_time[a][s][:]
        X = np.tile(np.arange(num_epochs), num_repeats)
        Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
        plt.scatter(X, Y, s=5)
        scheme_dirname = os.path.join("matlab", "granularity", wl, schemes[s])
        if not os.path.exists(scheme_dirname):
            os.makedirs(scheme_dirname)
        path_data = os.path.join(scheme_dirname, "allocation_time_scatter.csv")
        D = np.concatenate((X.reshape(-1, 1), Y), axis=1)
        np.savetxt(path_data, D, delimiter=",")
    plt.legend(schemes)
    plt.savefig(os.path.join(plot_dir, "allocation_time_scatter.png"))

    # search time scatter.
    plt.figure()
    plt.title("Allocation Search Time ({})".format(wl))
    plt.xlabel("Epoch")
    plt.ylabel("Time (ms)")
    plt.grid()
    for s in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            Y[: , a] = data_allocation_time[a][s][:]
        X = np.tile(np.arange(num_epochs), num_repeats)
        Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
        plt.scatter(X, Y, s=5)
        Y1 = np.mean(Y, axis=1)
        G = np.gradient(Y1)
        print("Search average gradient for {}: {}".format(schemes[s], np.mean(G)))
    plt.legend(schemes)
    plt.savefig(os.path.join(plot_dir, "search_time_scatter.png"))

    # # enumeration time scatter.
    # plt.figure()
    # plt.title("Enumeration Time ({})".format(wl))
    # plt.xlabel("Epoch")
    # plt.ylabel("Time (ms)")
    # plt.grid()
    # for s in range(num_schemes):
    #     Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    #     for a in range(num_repeats):
    #         Y[: , a] = data_enum_time[a][s][:]
    #     X = np.tile(np.arange(num_epochs), num_repeats)
    #     Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
    #     plt.scatter(X, Y, s=5)
    # plt.legend(schemes)
    # plt.savefig(os.path.join(plot_dir, "enum_time_scatter.png"))
    
    # # search loop scatter.
    # plt.figure()
    # plt.title("Search Iteration Time ({})".format(wl))
    # plt.xlabel("Epoch")
    # plt.ylabel("Time (ms)")
    # plt.grid()
    # for s in range(num_schemes):
    #     Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    #     for a in range(num_repeats):
    #         Y[: , a] = data_search_time[a][s][:]
    #     X = np.tile(np.arange(num_epochs), num_repeats)
    #     Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
    #     plt.scatter(X, Y, s=5)
    #     Y1 = np.mean(Y, axis=1)
    #     G = np.gradient(Y1)
    #     print("Search loop average gradient for {}: {}".format(schemes[s], np.mean(G)))
    # plt.legend(schemes)
    # plt.savefig(os.path.join(plot_dir, "search_iter_time_scatter.png"))

    # # post-processing time scatter.
    # plt.figure()
    # plt.title("Post-Processing Iteration Time ({})".format(wl))
    # plt.xlabel("Epoch")
    # plt.ylabel("Time (ms)")
    # plt.grid()
    # for s in range(num_schemes):
    #     Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    #     for a in range(num_repeats):
    #         Y[: , a] = data_pp_time[a][s][:]
    #     X = np.tile(np.arange(num_epochs), num_repeats)
    #     Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
    #     plt.scatter(X, Y, s=5)
    # plt.legend(schemes)
    # plt.savefig(os.path.join(plot_dir, "pp_time_scatter.png"))

    # apply time scatter.
    plt.figure()
    plt.title("Apply Time ({})".format(wl))
    plt.xlabel("Epoch")
    plt.ylabel("Time (ms)")
    plt.grid()
    for s in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            Y[: , a] = data_apply_time[a][s][:]
        X = np.tile(np.arange(num_epochs), num_repeats)
        Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
        plt.scatter(X, Y, s=5)
    plt.legend(schemes)
    plt.savefig(os.path.join(plot_dir, "apply_time_scatter.png"))

    # utilization average.
    plt.figure()
    plt.title("Workload: {}".format(wl))
    for i in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            for b in range(num_epochs):
                Y[b][a] = data_utilization[a][i][b]
        Y = np.nanmean(Y, axis=1)
        plt.plot(Y)
        scheme_dirname = os.path.join("matlab", "granularity", wl, schemes[i])
        path_utilization = os.path.join(scheme_dirname, "utilization.csv")
        np.savetxt(path_utilization, Y, delimiter=",")
    plt.xlabel("Epoch")
    plt.ylabel("Utilization")
    plt.legend(schemes)
    plt.grid()
    plt.savefig(os.path.join(plot_dir, "utilization.png"))

    # utilization scatter.
    plt.figure()
    plt.title("Workload: {}".format(wl))
    for i in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            Y[: , a] = data_utilization[a][i][:]
        X = np.tile(np.arange(num_epochs), num_repeats)
        Y = np.reshape(Y, (num_epochs * num_repeats, 1), order='F')
        plt.scatter(X, Y, s=5)
        # scheme_dirname = os.path.join("matlab", "granularity", wl, schemes[i])
        # path_utilization = os.path.join(scheme_dirname, "utilization.csv")
        # np.savetxt(path_utilization, Y, delimiter=",")
    plt.xlabel("Epoch")
    plt.ylabel("Utilization")
    plt.legend(schemes)
    plt.grid()
    plt.savefig(os.path.join(plot_dir, "utilization_scatter.png"))