#!/usr/bin/python

import os
import re
import glob

def get_time_seconds(ts):
    ts = ts.split(":")
    ts = int(ts[0]) * 3600 + int(ts[1]) * 60 + int(ts[2])
    return ts

requests = {}
servers = []

min_ts = 0
for file in glob.glob("ap4-server-*.csv"):
    server_id = re.search('ap4-server-(\d).csv', file)
    server_id = server_id.group(1) if server_id is not None else None
    if server_id not in servers:
        servers.append(server_id)
    with open(file) as f:
        data = f.read().strip().splitlines()
        for line in data:
            row = line.split(",")
            ts = row[0]
            req_count = int(row[1])
            if ts not in requests:
                requests[ts] = {}
            requests[ts][server_id] = req_count
            ts = get_time_seconds(ts)
            min_ts = ts if (min_ts == 0 or ts < min_ts) else min_ts
        f.close()

num_timstamps = len(requests.keys())
dataset = []

for ts in requests:
    ts_sec = get_time_seconds(ts)
    ts_offset = ts_sec - min_ts
    row = [0] * len(servers)
    for sid in requests[ts]:
        row[ servers.index(sid) ] = requests[ts][sid]
    dataset.append([ts_offset] + row)

dataset.sort(key = lambda x : x[0])

with open('server-dataset.csv', 'w') as out:
    out.write( "\n".join([ (",".join([str(x) for x in y])) for y in dataset ]) )
    out.close()