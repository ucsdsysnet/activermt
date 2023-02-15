#!/usr/bin/python3

import re
import sys
import json

LOGFILE = 'rte_log_active_bench.log'
OUTFILE = 'results.json'

CSVAPPS = 'results_times_apps.csv'
CSVFILE = 'results_allocation_times.csv'
MAPFILE = 'results_mapping.csv'

log = None

with open(LOGFILE) as f:
    log = f.read().strip().splitlines()
    f.close()

if log is None:
    print("[ERROR] unable to read log.")
    sys.exit(1)

apps = {}
series = {}

current_tick = None
current_fid = None
for line in log:
    if '[MAIN] tick' in line:
        tick = int(re.findall('tick ([0-9]+)', line)[0])
        series[tick] = set()
        current_tick = tick
    fid = re.findall("\[FID ([0-9]+)\]", line)
    if len(fid) == 0:
        continue
    fid = int(fid[0])
    if fid not in apps:
        apps[fid] = {
            'initiated'     : False,
            'allocation'    : None,
            'time'          : None,
            'program'       : None,
            'snapshots'     : []
        }
    if ' activating' in line:
        program = re.findall('program: ([a-z\-]+)', line)[0]
        apps[fid]['initiated'] = True
        apps[fid]['program'] = program
        current_fid = fid
        series[current_tick].add(fid)
    elif 'ALLOCATION' in line:
        apps[fid]['allocation'] = line
    elif ' allocation time' in line and apps[fid]['time'] is None:
        allocation_time = int(re.findall('([0-9]+) ns', line)[0])
        apps[fid]['time'] = allocation_time
    elif 'Snapshot complete' in line:
        snapshot_time = int(re.findall('([0-9]+) ns', line)[0])
        apps[current_fid]['snapshots'].append((fid, snapshot_time))

with open(OUTFILE, 'w') as f:
    f.write(json.dumps(apps, indent=4))
    f.close()

for fid in list(apps.keys()):
    if apps[fid]['time'] is None:
        apps.pop(fid)
    snapshot_total_time = 0
    for s in apps[fid]['snapshots']:
        snapshot_total_time += s[1]
    apps[fid]['snapshot_total'] = snapshot_total_time

results = [ "%d,%d,%d,%s" % (fid, apps[fid]['time'], apps[fid]['snapshot_total'], apps[fid]['program']) for fid in apps ]
with open(CSVAPPS, 'w') as f:
    f.write("\n".join(results))
    f.close()

n = len(list(series.keys()))
results = []
arrivals = []
for i in range(0, n):
    sum_time = 0
    sum_snapshots = 0
    for fid in series[i]:
        sum_time += apps[fid]['time']
        sum_snapshots += apps[fid]['snapshot_total']
        arrivals.append((i, fid))
    if len(series[i]) > 0:
        results.append((sum_time, sum_snapshots, len(series[i])))
    else:
        results.append((0, 0, 0))

with open(CSVFILE, 'w') as f:
    f.write("\n".join([ "%d,%d,%d" % (x[0], x[1], x[2]) for x in results ]))
    f.close()

with open(MAPFILE, 'w') as f:
    f.write("\n".join([ "%d,%d" % (x[0],x[1]) for x in arrivals ]))
    f.close()