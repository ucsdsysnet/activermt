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

DEBUG = False

if len(sys.argv) < 3:
    print("Usage: {} <data_dir> <config_path>".format(sys.argv[0]))
    sys.exit(1)

data_dir = sys.argv[1]
plot_dir = os.path.join(os.getcwd(), "evals/plots", os.path.basename(data_dir))
config_path = sys.argv[2]

if not os.path.exists(plot_dir):
    os.makedirs(plot_dir)

num_bins = 1000
num_epochs = 0
wl = None

schemes = []
with open(config_path, 'r') as f:
    config = json.load(f)
    num_epochs = config['epochs']
    num_repeats = config['repeats']
    wl = config['workload']
    for scheme in config['schemes']:
        schemes.append(scheme['fit'] if scheme['obj'] == 'fit' else scheme['obj'])
    f.close()

assert len(schemes) > 0

num_schemes = len(schemes)

data = {
    'utilization'   : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32),
    'reallocations' : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32),
    'reallocated'   : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32),
    'failrate'      : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32),
    'failures'      : [ [ [] for y in range(num_schemes) ] for x in range(num_repeats) ],
    'events'        : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32),
    'failed'        : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32),
    'fairness'      : np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
}

experiments = glob(os.path.join(data_dir, "*"))

assert(len(experiments) == num_repeats)

for exp in experiments:
    exp_idx = int(os.path.basename(exp))
    scheme_dirs = glob(os.path.join(exp, "*"))
    isElastic = {}
    for s in scheme_dirs:
        scheme_idx = int(os.path.basename(s))
        epochs = glob(os.path.join(s, "*"))
        for epoch in epochs:
            epoch_idx = int(os.path.basename(epoch))
            summary_path = os.path.join(epoch, "summary.csv")
            program_demands_path = os.path.join(epoch, "programs.csv")
            if os.path.exists(summary_path):
                summary = pd.read_csv(summary_path)
                data['reallocations'][exp_idx][scheme_idx][epoch_idx] = summary["changes"].values[0]
                data['reallocated'][exp_idx][scheme_idx][epoch_idx] = summary["reallocated_prop"].values[0]
                data['utilization'][exp_idx][scheme_idx][epoch_idx] = summary["utilization"].values[0]
                assert(summary["num_events"].values[0] >= summary["failures"].values[0]),"Inconsistent data for experiment {} scheme {} epoch {}".format(exp_idx, scheme_idx, epoch_idx)
                data['events'][exp_idx][scheme_idx][epoch_idx] = summary["num_events"].values[0]
                data['failed'][exp_idx][scheme_idx][epoch_idx] = summary["failures"].values[0]
                if summary["num_events"].values[0] > 0:
                    data['failrate'][exp_idx][scheme_idx][epoch_idx] = summary["failures"].values[0] / summary["num_events"].values[0]
            else:
                last_valid_epoch = epoch_idx - 1
                while last_valid_epoch > 0 and not os.path.exists(os.path.join(s, str(last_valid_epoch), "summary.csv")):
                    last_valid_epoch -= 1
                data['reallocations'][exp_idx][scheme_idx][epoch_idx] = np.nan
                data['reallocated'][exp_idx][scheme_idx][epoch_idx] = np.nan
                data['failed'][exp_idx][scheme_idx][epoch_idx] = np.nan
                data['utilization'][exp_idx][scheme_idx][epoch_idx] = data['utilization'][exp_idx][scheme_idx][last_valid_epoch]
            if os.path.exists(program_demands_path):
                try:
                    program_demands = pd.read_csv(program_demands_path, header=None)
                    for i in range(len(program_demands.values)):
                        fid = int(program_demands.values[i][0])
                        demand = int(program_demands.values[i][1])
                        isElastic[fid] = (demand == 1)
                except:
                    pass
    for i in range(num_schemes):
        for j in range(num_epochs):
            allocation_matrix_path = os.path.join(exp, str(i), str(j), "allocation_matrix.csv")
            if os.path.exists(allocation_matrix_path):
                M = pd.read_csv(allocation_matrix_path, header=None).values
                allocated_blocks = {}
                for a in range(len(M)):
                    for b in range(len(M[a])):
                        fid = M[a][b]
                        if fid > 0 and isElastic[fid]:
                            if fid not in allocated_blocks:
                                allocated_blocks[fid] = 0
                            allocated_blocks[fid] += 1
                x = np.array(list(allocated_blocks.values()), dtype=np.uint32)
                n = len(x)
                index = np.sum(x)**2 / (n * np.sum(np.square(x))) if n > 0 else 1
                data['fairness'][exp_idx][i][j] = index
            else:
                data['fairness'][exp_idx][i][j] = data['fairness'][exp_idx][i][j-1] if j > 0 else 1

# for k in range(num_repeats):
#     for i in range(num_schemes):
#         for j in range(num_epochs):
#             if j > 0 and data['utilization'][k][i][j] == 0:
#                 data['failures'][k][i].append([j, data['utilization'][k][i][j-1]])
#                 data['utilization'][k][i][j] = data['utilization'][k][i][j-1]
#         data['failures'][k][i] = np.array(data['failures'][k][i])

max_reallocations = int(np.nanmax(data['reallocations']))
num_bins = max_reallocations + 100

for scheme in schemes:
    scheme_dirname = os.path.join("matlab", scheme)
    if not os.path.exists(scheme_dirname):
        os.makedirs(scheme_dirname)

old_plots = glob(os.path.join(plot_dir, "*.png"))
for p in old_plots:
    print("Removing old plot {}".format(p))
    os.remove(p)

plt.rcParams.update({'font.size': 16})

plt.figure()
plt.title("Workload: {}".format(wl))
for i in range(num_schemes):
    Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            Y[b][a] = data['utilization'][a][i][b]
    Y = np.mean(Y, axis=1)
    plt.plot(Y)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_utilization = os.path.join(scheme_dirname, "utilization.csv")
    np.savetxt(path_utilization, Y, delimiter=",")
# for i in range(num_schemes):
#     Y = []
#     X = []
#     for a in range(num_epochs):
#         sum_failures = 0
#         for b in range(num_repeats):
#             sum_failures += len(data['failures'][b][i])
#     if data['failures'][i].size == 0:
#         continue
#     plt.scatter(data['failures'][i][:,0], data['failures'][i][:, 1], marker='x', color='black')
plt.xlabel("Epoch")
plt.ylabel("Utilization")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "utilization.png"))

plt.figure()
plt.title("Workload: {}".format(wl))
for i in range(num_schemes):
    Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            Y[b][a] = data['reallocations'][a][i][b]
    Y = np.mean(Y, axis=1)
    plt.scatter(range(num_epochs), Y, s=10)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_reallocations = os.path.join(scheme_dirname, "reallocations.csv")
    np.savetxt(path_reallocations, Y, delimiter=",")
plt.ylabel("Reallocations")
plt.xlabel("Epoch")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "reallocations.png"))

plt.figure()
plt.title("Workload: {}".format(wl))
for i in range(num_schemes):
    Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            Y[b][a] = data['reallocated'][a][i][b]
    Y = np.mean(Y, axis=1) * 100
    X = np.arange(num_epochs)
    # X = np.tile(np.arange(num_epochs), num_repeats)
    # Y = np.ravel(Y, order='F') * 100
    plt.scatter(X, Y, s=10, marker=5 + i)
    scheme_dirname = os.path.join("matlab", schemes[i])
    # path_reallocations = os.path.join(scheme_dirname, "reallocated_scatter_all.csv")
    path_reallocations = os.path.join(scheme_dirname, "reallocated.csv")
    np.savetxt(path_reallocations, Y, delimiter=",")
plt.ylabel("Reallocations (% of elastic)")
plt.xlabel("Epoch")
plt.legend(schemes)
plt.grid()
# plt.savefig(os.path.join(plot_dir, "reallocated_scatter_all.png"))
plt.savefig(os.path.join(plot_dir, "reallocated.png"))

if DEBUG:
    # TODO: remove debug
    plt.figure()
    scheme_id = 3
    scheme = schemes[scheme_id]
    plt.title("scheme: {}".format(scheme))
    Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            Y[b][a] = data['reallocated'][a][scheme_id][b]
    Y = np.mean(Y, axis=1) * 100
    X = np.arange(num_epochs)
    # X = np.tile(np.arange(num_epochs), num_repeats)
    # Y = np.ravel(Y, order='F') * 100
    plt.scatter(X, Y, s=10, marker=5 + i)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_reallocations = os.path.join(scheme_dirname, "reallocated.csv")
    np.savetxt(path_reallocations, Y, delimiter=",")
    plt.ylabel("Reallocations (% of elastic)")
    plt.xlabel("Epoch")
    plt.grid()
    plt.savefig(os.path.join(plot_dir, "reallocated_scheme_{}.png".format(scheme)))

    # TODO: remove debug
    data_events = np.zeros((num_repeats, num_schemes, num_epochs), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_schemes):
            for c in range(num_epochs):
                summary_path = os.path.join(data_dir, str(a), str(b), str(c), "summary.csv")
                if os.path.exists(summary_path):
                    summary = pd.read_csv(summary_path)
                    data_events[a][b][c] = summary['num_events'].values[0]
                else:
                    data_events[a][b][c] = 0
    plt.figure()
    for i in range(num_schemes):
        Y = np.zeros((num_epochs, num_repeats), dtype=np.float32)
        for a in range(num_repeats):
            for b in range(num_epochs):
                Y[b][a] = data_events[a][i][b]
        Y = np.mean(Y, axis=1)
        # Y = np.histogram(Y, bins=range(0, 10, 1))
        # Y = np.array(Y[0])
        # plt.plot(Y)
        # X = np.arange(num_epochs)
        # X = np.tile(np.arange(num_epochs), num_repeats)
        # Y = np.ravel(Y, order='F')
        plt.plot(Y)
        # plt.scatter(X, Y, s=5, marker=5 + i)
    plt.ylabel("Events")
    plt.xlabel("Epoch")
    # plt.xlabel("Events")
    # plt.ylabel("Frequency")
    plt.legend(schemes)
    plt.grid()
    plt.savefig(os.path.join(plot_dir, "events.png"))

    # TODO: remove debug
    plt.figure()
    plt.title("WF - Realloc")
    Y1 = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    Y2 = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            Y1[b][a] = data['reallocated'][a][1][b]
            Y2[b][a] = data['reallocated'][a][3][b]
    Y = np.mean(Y1-Y2, axis=1) * 100
    plt.scatter(range(num_epochs), Y, s=10)
    plt.ylabel("Reallocations (% of elastic)")
    plt.xlabel("Epoch")
    plt.grid()
    plt.savefig(os.path.join(plot_dir, "reallocated_debug.png"))

plt.figure()
# plt.title("Workload: {}".format(wl))
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['utilization'][a][i][b]
    utildata = np.reshape(D, (num_epochs * num_repeats, 1)) * 100
    Y = np.histogram(utildata, bins=range(0, 100, 1))
    Y = np.array(Y[0], dtype=float)
    Y /= np.sum(Y, dtype=float)
    CY = np.cumsum(Y)
    plt.plot(CY)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_utilization_cdf = os.path.join(scheme_dirname, "utilization_cdf.csv")
    np.savetxt(path_utilization_cdf, CY, delimiter=",")
plt.ylabel("CDF")
plt.xlabel("Utilization (%)")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "utilization_cdf.png"))

plt.figure()
# plt.title("Workload: {}".format(wl))
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['reallocations'][a][i][b]
    Y = np.histogram(np.reshape(D, (num_epochs * num_repeats, 1)), bins=range(0, num_bins, 1))
    Y = np.array(Y[0], dtype=float)
    Y /= np.sum(Y, dtype=float)
    CY = np.cumsum(Y)
    plt.plot(CY)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_reallocations_cdf = os.path.join(scheme_dirname, "reallocations_cdf.csv")
    np.savetxt(path_reallocations_cdf, CY, delimiter=",")
plt.ylabel("CDF")
plt.xlabel("Reallocations")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "reallocations_cdf.png"))

plt.figure()
# plt.title("Workload: {}".format(wl))
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['reallocated'][a][i][b] * 100
    Y = np.histogram(np.reshape(D, (num_epochs * num_repeats, 1)), bins=range(0, 100, 1))
    Y = np.array(Y[0], dtype=float)
    Y /= np.sum(Y, dtype=float)
    CY = np.cumsum(Y)
    plt.plot(CY)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_reallocations_cdf = os.path.join(scheme_dirname, "reallocated_cdf.csv")
    np.savetxt(path_reallocations_cdf, CY, delimiter=",")
plt.ylabel("CDF")
plt.xlabel("Reallocations (% of elastic))")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "reallocated_cdf.png"))

plt.figure()
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['failed'][a][i][b]
    Y = np.mean(D, axis=1)
    Y = np.cumsum(Y)
    plt.plot(Y)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_failures_cum = os.path.join(scheme_dirname, "failures_cum.csv")
    np.savetxt(path_failures_cum, Y, delimiter=",")
plt.xlabel("Epoch")
plt.ylabel("Cumulative failures")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "failures_cum.png"))

# plt.figure()
# for i in range(num_schemes):
#     D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
#     for a in range(num_repeats):
#         for b in range(num_epochs):
#             D[b][a] = data['failrate'][a][i][b]
#     Y = np.mean(D, axis=1)
#     plt.scatter(range(num_epochs), Y, s=3)
# plt.ylabel("Failure rate")
# plt.xlabel("Epoch")
# plt.legend(schemes)
# plt.grid()
# plt.rcParams.update({'font.size': 16})
# plt.savefig(os.path.join(plot_dir, "failures.png"))

plt.figure()
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['failrate'][a][i][b] * 100
    Y = np.histogram(np.reshape(D, (num_epochs * num_repeats, 1)), bins=range(0, 100, 1))
    Y = np.array(Y[0], dtype=float)
    Y /= np.sum(Y, dtype=float)
    CY = np.cumsum(Y)
    plt.plot(CY)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_failures_cdf = os.path.join(scheme_dirname, "failures_cdf.csv")
    np.savetxt(path_failures_cdf, CY, delimiter=",")
plt.ylabel("CDF")
plt.xlabel("Failure rate (%)")
plt.legend(schemes)
sz = plt.rcParams['figure.figsize']
plt.gcf().set_size_inches(sz[0] + 1, sz[1])
# plt.ylim(0, 1)
plt.grid()
plt.savefig(os.path.join(plot_dir, "failures_cdf.png"))

plt.rcParams.update({'font.size': 14})

plt.figure()
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['fairness'][a][i][b]
    Y = np.mean(D, axis=1)
    plt.plot(Y)
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_fairness = os.path.join(scheme_dirname, "fairness.csv")
    np.savetxt(path_fairness, Y, delimiter=",")
plt.xlabel("Epoch")
plt.ylabel("Fairness Index")
plt.legend(schemes)
plt.grid()
plt.savefig(os.path.join(plot_dir, "fairness.png"))

plt.figure()
Y = np.zeros((num_epochs * num_repeats, num_schemes), dtype=np.float32)
for i in range(num_schemes):
    D = np.zeros((num_epochs, num_repeats), dtype=np.float32)
    for a in range(num_repeats):
        for b in range(num_epochs):
            D[b][a] = data['fairness'][a][i][b]
    Y[:, i] = np.reshape(D, (1, num_epochs * num_repeats))
    scheme_dirname = os.path.join("matlab", schemes[i])
    path_fairness = os.path.join(scheme_dirname, "fairness_box.csv")
    np.savetxt(path_fairness, Y[:, i], delimiter=",")
plt.boxplot(Y, labels=schemes)
plt.ylabel("Fairness Index")
plt.grid()
plt.savefig(os.path.join(plot_dir, "fairness_box.png"))