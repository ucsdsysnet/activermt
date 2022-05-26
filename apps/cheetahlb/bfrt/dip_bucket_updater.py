import os
import time
import itertools

routing_file = '/usr/local/home/rajdeepd/activep4/apps/cheetahlb/env/ip_routing.csv'
sleep_time_sec = 0.01
duration_sec = 60

routes = {}
with open(routing_file) as f:
    entries = f.read().splitlines()
    for row in entries:
        record = row.split(',')
        ip_addr = record[0]
        dport = int(record[1]) # not used
        vport = record[2] 
        vport = int(vport) if vport != '' else None
        if vport is not None:
            routes[ip_addr] = vport
    f.close()

num_dips = len(routes.keys())

# group by VIPs

vips = {}

for ip in routes:
    ip_pfx = ip.split(".")[1:3]
    ip_pfx = (int(ip_pfx[0]) << 8) + int(ip_pfx[1])
    if ip_pfx not in vips:
        vips[ip_pfx] = []
    vips[ip_pfx].append(routes[ip])

print(vips)

p4 = bfrt.active.pipe

# update VIP buckets

permutations = None
permidx = 0
num_perms = 0
elapsed_sec = 0
ts_then = time.time()
while(elapsed_sec < duration_sec):
    idx = 0
    for vip in vips:
        bucket = vips[vip]
        if permutations is None:
            permutations = list(itertools.permutations(bucket))
            num_perms = len(permutations)
        bucket = permutations[permidx]
        permidx = (permidx + 1) % num_perms
        #print(bucket)
        BUCKET_SIZE = len(bucket)
        offset = idx * BUCKET_SIZE
        p4.Ingress.heap_s1.add(REGISTER_INDEX=vip, f1=0) # bucket counter
        p4.Ingress.heap_s4.add(REGISTER_INDEX=vip, f1=offset) # bucket offset
        for dst in range(0, BUCKET_SIZE):
            dst_idx = offset + dst
            p4.Ingress.heap_s6.add(REGISTER_INDEX=dst_idx, f1=bucket[dst]) # DIP vport
        idx = idx + 1
    bfrt.complete_operations()
    time.sleep(sleep_time_sec)
    elapsed_sec = time.time() - ts_then

print("bucket updater terminated.")