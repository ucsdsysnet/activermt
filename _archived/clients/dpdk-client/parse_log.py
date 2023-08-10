#!/usr/bin/python3

import re

LOGFILENAME = "rte_log_activep4.log"
OUTFILENAME_ALLOCATIONS = "activep4_allocations.csv"
OUTFILENAME_SNAPSHOTS = "activep4_snapshots.csv"

with open(LOGFILENAME) as f:
    timings = {
        'allocation'    : {},
        'reallocation'  : {},
        'snapshots'     : {}
    }
    entries = f.read().strip().splitlines()
    currentSnapshots = []
    for entry in entries:
        matches = re.findall("\[FID ([0-9]+)\]", entry)
        if len(matches) == 0 or int(matches[0]) >= 253:
            continue
        else:
            fid = int(matches[0])
        if " allocation time " in entry:
            tokens = entry.split(" ")
            time_ns = int(tokens[4])
            timings['allocation'][fid] = time_ns
            timings['snapshots'][fid] = currentSnapshots
            currentSnapshots = []
        elif "Snapshot complete" in entry:
            matches = re.findall("([0-9]+) ns", entry)
            duration_ms = int(matches[0]) / 1E6 if len(matches) > 0 else None
            currentSnapshots.append((fid, duration_ms))
    f.close()

    with open(OUTFILENAME_ALLOCATIONS, "w") as g:
        data = []
        for fid in timings['allocation']:
            data.append("%d,%d" % (fid, timings['allocation'][fid]))
        g.write("\n".join(data))
        g.close()

    with open(OUTFILENAME_SNAPSHOTS, "w") as f:
        data = []
        for fid in timings['snapshots']:
            sum_times_ms = 0
            for s in timings['snapshots'][fid]:
                sum_times_ms += s[1]
            data.append((fid, sum_times_ms, len(timings['snapshots'][fid])))
        f.write("\n".join([ ",".join([ str(y) for y in x ]) for x in data ]))
        f.close()

    print("Snapshots", timings['snapshots'])