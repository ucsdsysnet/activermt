#!/usr/bin/python3

import os

LOGFILENAME = "rte_log_activep4.log"
OUTFILENAME_ALLOCATIONS = "activep4_allocations.csv"

with open(LOGFILENAME) as f:
    timings = {
        'allocation'    : {},
        'reallocation'  : {},
        'snapshot'      : {}
    }
    entries = f.read().strip().splitlines()
    for entry in entries:
        if " allocation time " in entry:
            tokens = entry.split(" ")
            fid = int(tokens[1][:-1])
            time_ns = int(tokens[4])
            timings['allocation'][fid] = time_ns
    f.close()

    with open(OUTFILENAME_ALLOCATIONS, "w") as g:
        data = []
        for fid in timings['allocation']:
            data.append("%d,%d" % (fid, timings['allocation'][fid]))
        g.write("\n".join(data))
        g.close()