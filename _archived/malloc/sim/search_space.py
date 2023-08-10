#!/usr/bin/python3

import os
import sys
import json

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))

from allocator import ActiveFunction
from utils import Util

util = Util()

appconfig = None
appconfig_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'apps.json')
assert(os.path.exists(appconfig_path))
with open(appconfig_path, 'r') as f:
    appconfig = json.load(f)
    f.close()
assert(appconfig is not None)

util.readInstructionSet()

# main.

def encode_memidx(memidx):
    value = 0
    for idx in memidx:
        value |= (1 << idx)
    return value

apps = {}
fid = 0
for appname in appconfig:
    fid += 1
    config = appconfig[appname]
    util.readProgram(config['source'], program_name=appname)
    constraints = util.buildConstraints(appname, config['demand'])
    apps[appname] = ActiveFunction(fid, constraints['memidx'], constraints['iglim'], constraints['length'], constraints['mindemand'], enumerate=True, allow_filling=True)

mutants = {}

for app in apps:
    print("Number of mutants for app {}: {}".format(app, apps[app].getEnumerationSize()))
    enumeration = apps[app].getEnumeration(transformed=True)
    mutants[app] = enumeration
    # region = 2**apps[app].num_stages
    # buckets = np.zeros((region, 1), dtype=np.uint16)
    # for mutant in enumeration:
    #     xval = encode_memidx(mutant)
    #     buckets[xval] += 1
    # pdf = buckets / np.sum(buckets)
    # plt.figure()
    # plt.plot(pdf)
    # plt.xlabel('x')
    # plt.ylabel('P(x)')
    # plt.savefig('{}/pdf_{}.png'.format(os.path.join(os.getcwd(), 'plots'), app))

# f(x1, x2, ... xn) = 0, for valid allocation and xi is a valid point for each app i.
# exhaustive search time = |X1| * |X2| * ... * |Xn|
# stochastic search : e.g. MCMC; draw a x from each Xi with certain probability. 

def feasible(alloc):
    acc = set()
    for x in alloc:
        for m in x:
            if m in acc:
                return False
            acc.add(m)
    return True

def cost(alloc):
    NUM_STAGES = 20
    mmap = np.zeros((NUM_STAGES, 1), dtype=np.uint16)
    for x in alloc:
        for m in x:
            mmap[m] += 1
    return np.sum(np.square(mmap))

num_apps = len(apps)

# for speeding up.
ideal_cost = 0
for app in apps:
    ideal_cost += cost([mutants[app][0]])

# 1. Enumeration suffices for 10+10 stages: ~64k mutants in the limit.
# 2. Search space explodes when multiple apps are considered.
# probability of finding a feasible allocation in k iterations?

max_iter = 1000
num_repeats = 1000

rng = np.random.default_rng()

success = np.zeros((int(np.log10(max_iter)) + 1, 1), dtype=np.float32)

optimal_costs = np.zeros((num_repeats, 1), dtype=np.uint32)
overlapping_costs = np.zeros((num_repeats, 1), dtype=np.uint16)
for r in range(num_repeats):
    min_cost = np.inf
    optimal = None
    # in the limit, will produce optimal.
    for i in range(max_iter):
        # monte carlo search.
        alloc = []
        for app in apps:
            # since drawn from enumerations, all samples are equally likely?
            idx = int(rng.random() * len(mutants[app]))
            # idx = rng.randint(len(mutants[app]))
            alloc.append(mutants[app][idx])
        c = cost(alloc)
        if c < min_cost:
            min_cost = c
            optimal = alloc
        # speed up.
        if min_cost == ideal_cost:
            break
    overlapping_costs[r] = int(feasible(optimal))
    optimal_costs[r] = min_cost

success_rate = np.sum(overlapping_costs) / num_repeats

# X = []
# Y = []
# for r in range(num_repeats):
#     if overlapping_costs[r] == 1:
#         X.append(r)
#         Y.append(optimal_costs[r])

plt.figure()
plt.title('Success rate: {}'.format(success_rate))
plt.scatter(range(num_repeats), optimal_costs, marker='.')
# plt.plot(optimal_costs)
# plt.scatter(X, Y, marker='x')
plt.xlabel('Iteration')
plt.ylabel('Cost')
plt.savefig('{}/optimal_costs_niter_{}.png'.format(os.path.join(os.getcwd(), 'plots', 'search'), max_iter))

print("Success rate (optimal): {}".format(np.sum(overlapping_costs) / num_repeats))