import os

routing_file = '/usr/local/home/rajdeepd/activep4/config/ip_routing_lxc.csv'

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

# install VIP buckets

idx = 0
for vip in vips:
    BUCKET_SIZE = len(vips[vip])
    offset = idx * BUCKET_SIZE
    p4.Ingress.heap_s1.add(REGISTER_INDEX=idx, f1=0) # bucket counter
    p4.Ingress.heap_s4.add(REGISTER_INDEX=idx, f1=offset) # bucket offset
    for dst in range(0, BUCKET_SIZE):
        dst_idx = offset + dst
        p4.Ingress.heap_s6.add(REGISTER_INDEX=dst_idx, f1=vips[vip][dst]) # DIP vport
    idx = idx + 1

bfrt.complete_operations()