from time import time

PAGE_SIZE = 8192

ts_start_sync = time()
p4_pd.register_hw_sync_heap_1()
ts_stop_sync = time()
elapsed_sync = ts_stop_sync - ts_start_sync

ts_start_singleread = time()
p4_pd.register_read_heap_1(0, from_sw)
ts_stop_singleread = time()
elapsed_singleread = ts_stop_singleread - ts_start_singleread

ts_start_read = time()
data = p4_pd.register_range_read_heap_1(0, PAGE_SIZE, from_sw)
ts_stop_read = time()
elapsed_read = ts_stop_read - ts_start_read

ts_start_reset = time()
p4_pd.register_range_reset_heap_1(0, PAGE_SIZE)
ts_stop_reset = time()
elapsed_reset = ts_stop_reset - ts_start_reset

ts_start_write = time()
for i in range(0, PAGE_SIZE):
    p4_pd.register_write_heap_1(i, data[i])
ts_stop_write = time()
elapsed_write = ts_stop_write - ts_start_write

elapsed_total = elapsed_sync + elapsed_read + elapsed_reset + elapsed_write

print "TIMINGS:"
print "sync\t: %f" % elapsed_sync
print "read\t: %f" % elapsed_read
print "reset\t: %f" % elapsed_reset
print "write\t: %f" % elapsed_write
print "total\t: %f" % elapsed_total
print ""
print "read single : %f" % elapsed_singleread
print ""