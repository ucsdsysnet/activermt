from time import time
import math

def update_dip_pool(mem_space, num_servers):
    obj = p4_pd.register_read_heap_1(0, from_sw)[0]
    for i in range(0, mem_space):
        obj.f1 = i
        obj.f0 = num_servers - 1 # pool size mask
        p4_pd.register_write_heap_1(i, obj)
        obj.f0 = num_servers * math.floor(i / num_servers) # base location
        p4_pd.register_write_heap_10(i, obj)
        obj.f0 = (i % num_servers) + 1 # dip port
        p4_pd.register_write_heap_8(i, obj)
    conn_mgr.complete_operations()

update_dip_pool(16, 4)