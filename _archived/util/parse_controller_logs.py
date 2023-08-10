#!/usr/bin/python3

import os
import sys
import re
import json

BASE_PATH = "../logs/controller"
LOGFILE = "controller.log"

if len(sys.argv) > 1:
    LOGFILE = sys.argv[1]

logpath = os.path.join(BASE_PATH, LOGFILE)

allocation_times = {}
snapshot_times = {}

with open(logpath) as f:
    lines = f.read().splitlines()
    currently_allocating = None
    for line in lines:
        matches = re.findall("\[FID ([0-9]+)\]", line)
        if len(matches) == 0 or int(matches[0]) >= 253:
            continue
        else:
            fid = matches[0]
        if "allocation init" in line:
            currently_allocating = fid
            snapshot_times[fid] = {}
        elif "allocation complete" in line:
            matches = re.findall("version ([0-9]+)", line)
            version = matches[0] if len(matches) > 0 else None
            matches = re.findall("elapsed time ([0-9.]+) ms", line)
            duration_ms = matches[0] if len(matches) > 0 else None
            allocation_times[fid] = (version, duration_ms)
            currently_allocating = None
            # print("FID", fid, "version", version, "time (ms)", duration_ms)
        elif "snapshot complete" in line:
            matches = re.findall("elapsed time ([0-9.]+) ms", line)
            duration_ms = matches[0] if len(matches) > 0 else None
            if currently_allocating is None:
                raise Exception("Corrupt log sequence!")
            snapshot_times[currently_allocating][fid] = duration_ms
    f.close()

with open(os.path.join(BASE_PATH, "allocation_times_controller.csv"), "w") as f:
    f.write("\n".join([ "%s,%s" % (x, allocation_times[x][1]) for x in allocation_times ]))
    f.close()

print(json.dumps(snapshot_times, indent=4))