import os

KEYSPACE = 65536
NUM_PIPES = 4

counters = p4_pd.register_range_read_heap_10(0, KEYSPACE, from_hw)

PIPE_IDX = 1

num_hits = 0

for i in range(0, KEYSPACE):
    if i16_to_hex(counters[ NUM_PIPES * i + PIPE_IDX ].f0) > 0:
        num_hits = num_hits + 1

print "%d counters were hit" % num_hits

conn_mgr.complete_operations()