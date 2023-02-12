#!/usr/bin/python3

import re
import sys
import json

LOGFILE = 'rte_log_active_bench.log'
OUTFILE = 'results.json'

CSVFILE = 'results_allocation_times.csv'

log = None

with open(LOGFILE) as f:
    log = f.read().strip().splitlines()
    f.close()

if log is None:
    print("[ERROR] unable to read log.")
    sys.exit(1)

apps = {}

for line in log:
    fid = re.findall("\[FID ([0-9]+)\]", line)
    if len(fid) == 0:
        continue
    fid = int(fid[0])
    if fid not in apps:
        apps[fid] = {
            'initiated'     : False,
            'allocation'    : None,
            'time'          : None,
            'program'       : None
        }
    if 'activating' in line:
        program = re.findall('program: ([a-z\-]+)', line)[0]
        apps[fid]['initiated'] = True
        apps[fid]['program'] = program
    elif 'ALLOCATION' in line:
        apps[fid]['allocation'] = line
    elif 'allocation time' in line:
        allocation_time = int(re.findall('([0-9]+) ns', line)[0])
        apps[fid]['time'] = allocation_time

with open(OUTFILE, 'w') as f:
    f.write(json.dumps(apps, indent=4))
    f.close()

results = [ "%d,%d,%s" % (fid, apps[fid]['time'], apps[fid]['program']) for fid in apps ]
with open(CSVFILE, 'w') as f:
    f.write("\n".join(results))
    f.close()