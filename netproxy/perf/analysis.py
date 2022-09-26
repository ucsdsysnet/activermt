#!/usr/bin/python3

import os
import sys
import json

data_tun = []
data_direct = []
data_active = []

with open('direct.json') as f:
    data = json.loads(f.read())
    data_direct = data['intervals']
    f.close()

with open('tun.json') as f:
    data = json.loads(f.read())
    data_tun = data['intervals']
    f.close()

with open('active.json') as f:
    data = json.loads(f.read())
    data_active = data['intervals']
    f.close()

num_intervals = len(data_direct)

data_comparison = []

for i in range(0, num_intervals):
    a = data_direct[i]['sum']['bits_per_second']
    b = data_tun[i]['sum']['bits_per_second']
    c = data_active[i]['sum']['bits_per_second']
    data_comparison.append((a, b, c))

with open('direct_vs_tun_vs_active.csv', 'w') as f:
    f.write("\n".join([ ",".join([ str(y) for y in x ]) for x in data_comparison ]))
    f.close()