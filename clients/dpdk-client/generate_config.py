#!/usr/bin/python3

import os
import sys
import random

random.seed()

known_paths = {
    'cacheread'     : '../../apps/cache/active',
    'freqitem'      : '../../apps/scenario_distcache/active',
    'cheetahlb-syn' : '../../apps/cheetahlb/active'
}

known_apps = list(known_paths.keys())

num_apps = 1 if len(sys.argv) < 2 else int(sys.argv[1])
appname = "cacheread" if len(sys.argv) < 3 else sys.argv[2]
port_start = 5678 if len(sys.argv) < 4 else int(sys.argv[3])

if appname not in known_paths and appname != 'random':
    raise Exception("Unknown app/workload!")

apps = []

for i in range(0, num_apps):
    if appname == 'random':
        sampled = random.sample(known_apps, k=1)[0]
        apps.append((sampled, known_paths[sampled]))
    else:
        apps.append((appname, known_paths[appname]))

config = []

for i in range(0, num_apps):
    appname = apps[i][0]
    base_path = apps[i][1]
    config.append("%d,%s,%s,%d" % (i + 1, base_path, appname, port_start + i))

with open("config.csv", "w") as f:
    f.write("\n".join(config))
    f.close()