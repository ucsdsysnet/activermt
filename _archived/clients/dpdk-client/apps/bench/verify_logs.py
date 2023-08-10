#!/usr/bin/python3

import re
import sys
import copy

LOGFILE_CONTROLLER = '../../../../logs/controller/controller-asic.log'
LOGFILE_CLIENT = 'rte_log_active_bench.log'
DEBUG_DIR_CONTROLLER = '../../../../logs/controller/debug'
NUM_TICKS = 30

log_client = None
log_controller = None

with open(LOGFILE_CLIENT) as f:
    log_client = f.read().strip().splitlines()
    f.close()

with open(LOGFILE_CONTROLLER) as f:
    log_controller = f.read().strip().splitlines()
    f.close()

if log_client is None or log_controller is None:
    print("[ERROR] unable to read logs.")
    sys.exit(1)

# verify that inelastic applications are not reallocated.

APP_TYPES_INELASTIC = {
    'cacheread'     : False,
    'freqitem'      : True,
    'cheetahlb-syn' : True
}

apps = {}

is_inelastic = {}

for line in log_client:
    fid = re.findall("\[FID ([0-9]+)\]", line)
    if len(fid) == 0:
        continue
    fid = int(fid[0])
    if fid not in apps:
        apps[fid] = {
            'program'       : None
        }
    if 'activating' in line:
        program = re.findall('program: ([a-z\-]+)', line)[0]
        apps[fid]['program'] = program
        is_inelastic[fid] = APP_TYPES_INELASTIC[program]

A = []
for i in range(0, NUM_TICKS):
    with open('%s/allocmatrix_%d.csv' % (DEBUG_DIR_CONTROLLER, i + 1)) as f:
        lines = f.read().strip().splitlines()
        a = [ [ int(x) for x in line.split(',') ] for line in lines ]
        A.append(a)
        f.close()

for fid in is_inelastic:
    if not is_inelastic[fid]:
        continue
    for k in range(1, len(A)):
        current = A[k - 1]
        a = A[k]
        num_blocks = len(a)
        num_stages = len(a[0])
        for i in range(0, num_blocks):
            for j in range(0, num_stages):
                id_new = a[i][j]
                id_old = current[i][j]
                if (id_old == fid) and (id_new != id_old):
                    raise Exception("Inelastic constraint violated: FID %d allocation %d -> %d index (%d,%d) change (%d,%d)" % (fid, k - 1, k, i, j, id_old, id_new)) 