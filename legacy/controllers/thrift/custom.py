from time import time

CLEAR_INTERVAL_SEC = 1

obj = p4_pd.register_read_heap_1(0, from_sw)[0]
obj.f0 = 0
obj.f1 = 0

then = time()
while True:
    now = time()
    elapsed = now - then
    if elapsed >= CLEAR_INTERVAL_SEC:
        start = time()
        p4_pd.register_write_all_heap_2(obj)
        p4_pd.register_write_all_heap_5(obj)
        p4_pd.register_write_all_heap_6(obj)
        p4_pd.register_write_all_heap_9(obj)
        conn_mgr.complete_operations()
        stop = time()
        clear_time = (stop - start) * 1000
        then = now
        #print "cleared registers in %d ms" % clear_time
