#!/usr/bin/python3

import sys
import os
import numpy as np

from multiprocessing import Process

params_constr = ['lc', 'mc']
# params_wl = ['random', 'elastic', 'inelastic']
params_wl = ['random']

wl = sys.argv[1] if len(sys.argv) > 1 else 'random'
wl = wl if wl in params_wl else 'random'

NUM_REPEATS = 10
DIRNAME_FMT = 'timesimulation_stats_g368_t1000_%s_wf_%s_a2'

is_inelastic = {
    'freqitem'  : True,
    'cheetahlb' : True,
    'cache'     : False
}

def process_experiment(dirname, trial):
    print("processing %s trial %d ... " % (dirname, trial))
    filename_appnames = os.path.join(dirname, str(trial), 'appnames.csv')
    filename_arrivals = os.path.join(dirname, str(trial), 'arrivals.csv')
    filename_elasticity = os.path.join(dirname, str(trial), 'elasticity.csv')
    allocation_matrix_dir = os.path.join(dirname, str(trial), 'allocations')
    apps = {}
    with open(filename_appnames) as f:
        for row in f.read().strip().splitlines():
            app = row.split(',')
            apps[int(app[0])] = app[1]
        f.close()
    arrivals = []
    last_arrival = None
    with open(filename_arrivals) as f:
        for line in f.read().strip().splitlines():
            fids = [ int(x) for x in line.split(',') ] if len(line) > 0 else []
            last_arrival = last_arrival if len(fids) == 0 else fids[-1]
            arrivals.append(last_arrival)
        f.close()
    # elastic_blocks = []
    # matrices = []
    # for fid in arrivals:
    #     current_matrix = None
    #     if fid is None:
    #         elastic_blocks.append({0:0})
    #         continue
    #     filename_allocmatrix = os.path.join(allocation_matrix_dir, 'allocmatrix_%d.csv' % (fid - 1))
    #     with open(filename_allocmatrix) as f:
    #         matrix = [ [ int(x) for x in row.split(',') ] for row in f.read().strip().splitlines() ]
    #         matrix = np.matrix(matrix, dtype=np.uint16)
    #         if matrix.size > 0:
    #             current_matrix = matrix
    #             dim = matrix.shape
    #             num_blocks = {}
    #             for i in range(0, dim[0]):
    #                 for j in range(0, dim[1]):
    #                     tid = matrix[i, j]
    #                     if tid == 0 or is_inelastic[apps[tid]]:
    #                         continue
    #                     if tid not in num_blocks:
    #                         num_blocks[tid] = 0
    #                     num_blocks[tid] += 1
    #             if len(num_blocks) == 0:
    #                 num_blocks = {0:0}
    #             elastic_blocks.append(num_blocks)
    #         else:
    #             raise Exception("Empty allocation matrix for FID %d!" % fid)
    #         f.close()
    #     matrices.append(current_matrix)
    num_ticks = 0
    filename_alloctime = os.path.join(dirname, str(trial), 'alloctime.csv')
    with open(filename_alloctime) as f:
        num_ticks = len(f.read().strip().splitlines())
        f.close()
    num_apps_total = []
    num_apps_elastic = []
    num_apps_reallocated = []
    fairness = []
    current_matrix = None
    for t in range(0, num_ticks):
        filename_allocmatrix = os.path.join(allocation_matrix_dir, 'allocmatrix_%d.csv' % t)
        with open(filename_allocmatrix) as f:
            matrix = [ [ int(x) for x in row.split(',') ] for row in f.read().strip().splitlines() ]
            matrix = np.matrix(matrix, dtype=np.uint16)
            if matrix.size == 0:
                raise Exception("Empty allocation matrix for interval %d!" % t)
            dim = matrix.shape
            elastic_blocks = {}
            previous_occupants = set()
            total_occupants = set()
            elastic_occupants = set()
            reallocated = set()
            for i in range(0, dim[0]):
                for j in range(0, dim[1]):
                    tid = matrix[i, j]
                    tid_prev = current_matrix[i, j] if current_matrix is not None else None
                    if tid_prev is not None and tid_prev != 0:
                        previous_occupants.add(tid_prev)
                    if tid != 0:
                        total_occupants.add(tid)
                    if tid == 0 or is_inelastic[apps[tid]]:
                        continue
                    elastic_occupants.add(tid)
                    if current_matrix is not None:
                        if tid != tid_prev:
                            reallocated.add(tid_prev)
                    if tid not in elastic_blocks:
                        elastic_blocks[tid] = 0
                    elastic_blocks[tid] += 1
            x = np.array([ elastic_blocks[a] for a in elastic_blocks ], dtype=np.float32)
            n = len(x)
            index = np.sum(x)**2 / (n * np.sum(np.square(x))) if n > 0 else 1
            fairness.append(index)
            num_apps_total.append(len(total_occupants))
            num_apps_elastic.append(len(elastic_occupants))
            if current_matrix is None:
                num_apps_reallocated.append(0)
            else:
                reallocated_pruned = set()
                for a in reallocated:
                    if a in total_occupants and a in previous_occupants:
                        reallocated_pruned.add(a)
                num_apps_reallocated.append(len(reallocated_pruned))
            current_matrix = matrix
    filename_reallocations = os.path.join(dirname, str(trial), 'reallocations.csv')
    with open(filename_reallocations, 'w') as f:
        f.write("\n".join([ '%d,%d,%d' % (num_apps_reallocated[r], num_apps_total[r], num_apps_elastic[r]) for r in range(0, num_ticks) ]))
        f.close()
    # matrices = {}
    # for fid in list(apps.keys()):
    #     filename_allocmatrix = os.path.join(allocation_matrix_dir, 'allocmatrix_%d.csv' % (fid - 1))
    #     with open(filename_allocmatrix) as f:
    #         matrix = [ [ int(x) for x in row.split(',') ] for row in f.read().strip().splitlines() ]
    #         matrices[fid] = np.matrix(matrix, dtype=np.uint16)
    #         f.close()
    # compute fairness.
    # blocks = {}
    # for id in matrices:
    #     matrix = matrices[id]
    #     if matrix.size == 0:
    #         continue
    #     dim = matrix.shape
    #     num_blocks = {}
    #     for i in range(0, dim[0]):
    #         for j in range(0, dim[1]):
    #             fid = matrix[i, j]
    #             if fid == 0 or is_inelastic[apps[fid]]:
    #                 continue
    #             if fid not in num_blocks:
    #                 num_blocks[fid] = 0
    #             num_blocks[fid] += 1
    #     blocks[id] = num_blocks
    # write blocks.
    # filename_blocks = os.path.join(dirname, str(trial), 'allocated_blocks.csv')
    # with open(filename_blocks, 'w') as f:
    #     f.write("\n".join([ ",".join([ str(alloc[aid]) for aid in alloc ]) for alloc in elastic_blocks ]))
    #     f.close()
    # # compute fairness index.
    # fairness = []
    # for blocks in elastic_blocks:
    #     x = np.array([ blocks[id] for id in blocks ], dtype=np.float32)
    #     n = len(x)
    #     index = np.sum(x)**2 / (n * np.sum(np.square(x)))
    #     fairness.append(index)
    filename_fairness = os.path.join(dirname, str(trial), 'fairness.csv')
    with open(filename_fairness, 'w') as f:
        f.write("\n".join([ str(x) for x in fairness ]))
        f.close()

# process each wl.
threads = []
for i in range(0, len(params_wl)):
    for j in range(0, len(params_constr)):
        for r in range(0, NUM_REPEATS):
            dirname = DIRNAME_FMT % (params_wl[i], params_constr[j])
            th = Process(target=process_experiment, args=(dirname, r))
            th.start()
            threads.append(th)

for th in threads:
    th.join()