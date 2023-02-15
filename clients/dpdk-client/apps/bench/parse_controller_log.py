#!/usr/bin/python3

import re
import sys
import json

LOGFILE = 'controller-asic-diff.log'
OUTFILE = 'asic_log.json'
CSVFILE = 'results_controller.csv'

log = None

with open(LOGFILE) as f:
    log = f.read().strip().splitlines()
    f.close()

if log is None:
    print("[ERROR] unable to read log.")
    sys.exit(1)

apps = {}

current_fid = None

pos = 0
for line in log:
    fid = re.findall("\[FID ([0-9]+)\]", line)
    if len(fid) == 0:
        continue
    fid = int(fid[0])
    if 'enqueued allocation' in line:
        if fid not in apps:
            apps[fid] = {
                'initiated'     : False,
                'allocation'    : None,
                'reallocations' : None,
                'time'          : None,
                'program'       : None,
                'timeout'       : False,
                'acks'          : []
            }
        apps[fid]['initiated'] = True
        current_fid = fid
    elif 'allocation:' in line:
        apps[fid]['allocation'] = line
    elif 'reallocations:' in line:
        apps[fid]['reallocations'] = line[line.index('reallocations:') + len('reallocations:'):].strip()
    elif 'reallocation timeout' in line:
        apps[fid]['timeout'] = True
    elif 'reallocation ack' in line:
        if current_fid is not None:
            apps[current_fid]['acks'].append(fid)
    elif 'allocation complete' in line:
        allocation_time = float(re.findall('([0-9.]+) ms', line)[0])
        apps[fid]['time'] = allocation_time

with open(OUTFILE, 'w') as f:
    f.write(json.dumps(apps, indent=4))
    f.close()

results = [ "%d,%d" % (fid, apps[fid]['time']) for fid in apps ]
with open(CSVFILE, 'w') as f:
    f.write("\n".join(results))
    f.close()