from time import time

MAX_ENTRIES = 16

fetch = [
    p4_pd.register_range_read_heap_1,
    p4_pd.register_range_read_heap_2,
    p4_pd.register_range_read_heap_3,
    p4_pd.register_range_read_heap_4,
    p4_pd.register_range_read_heap_5,
    p4_pd.register_range_read_heap_6,
    p4_pd.register_range_read_heap_7,
    p4_pd.register_range_read_heap_8,
    p4_pd.register_range_read_heap_9,
    p4_pd.register_range_read_heap_10,
    p4_pd.register_range_read_heap_11
]

#allowed = [1, 7, 8, 10]
allowed = [5, 8, 10]

start = time()
data_heap = []
headers = []
for i in range(0, 11):
    if (i + 1) not in allowed:
        continue
    headers.append("S%d" % (i + 1))
    data_heap.append(fetch[i](0, MAX_ENTRIES, from_hw))
conn_mgr.complete_operations()
end = time()
elapsed = end - start
print "%d seconds elapsed" % elapsed

print "[MEMORY DUMP]"
print ""
print "\t".join(headers)

for i in range(0, MAX_ENTRIES):
    row = []
    for j in range(0, len(data_heap)):
        row.append(str(i16_to_hex(data_heap[j][4 * i + 1].f0)))
    print "\t".join(row)

print ""