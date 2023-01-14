#!/usr/bin/python3

import sys

num_apps = 1 if len(sys.argv) < 2 else int(sys.argv[1])
base_path = "../../apps/cache/active" if len(sys.argv) < 3 else int(sys.argv[2])
appname = "cacheread" if len(sys.argv) < 4 else int(sys.argv[3])
port_start = 5678 if len(sys.argv) < 5 else int(sys.argv[4])

config = []

for i in range(0, num_apps):
    config.append("%d,%s,%s,%d" % (i + 1, base_path, appname, port_start + i))

with open("config.csv", "w") as f:
    f.write("\n".join(config))
    f.close()