import atexit
import time
import threading

digest = 0
running = True

cir_gbps = 20
cir_kbps = cir_gbps * 1024 * 1024
cir_kbits = 65536
pir_kbps = 2 * cir_kbps
pir_kbits = 65536

addr = "192.168.1.1"
port = 188

mutex = threading.Lock()

def at_exit():
    global digest, mutex, running
    running = False
    mutex.acquire()
    p4_pd.meter_params_digest_notify_ack(digest.msg_ptr)
    p4_pd.meter_params_deregister()
    mutex.release()
    print("unregistered handler")

atexit.register(at_exit)

clear_all()

p4_pd.forward_table_add_with_setegr(
    p4_pd.forward_match_spec_t(
        ipv4Addr_to_i32(addr),
        32
    ),
    p4_pd.setegr_action_spec_t(port)
)
p4_pd.traffic_set_default_action_trafficupdate()
p4_pd.filter_meter_table_add_with_dofilter_meter(
    p4_pd.filter_meter_match_spec_t(
        meta_color=1
    )
)
p4_pd.filter_meter_table_add_with_dofilter_meter(
    p4_pd.filter_meter_match_spec_t(
        meta_color=2
    )
)
p4_pd.monitor_table_add_with_report(
    p4_pd.monitor_match_spec_t(
        meta_digest=1
    )
)

p4_pd.register_reset_all_bloom_meter()
p4_pd.meter_set_traffic_monitor(
    0,
    p4_pd.bytes_meter_spec_t(cir_kbps, cir_kbits, pir_kbps, pir_kbits, False)
)
conn_mgr.complete_operations()

p4_pd.meter_params_register()
while True:
    if not running:
        break
    mutex.acquire()
    digest = p4_pd.meter_params_get_digest()
    mutex.release()
    if digest.msg != []:
        msg_ptr = digest.msg_ptr
        digest.msg_ptr = 0
        mutex.acquire()
        p4_pd.meter_params_digest_notify_ack(msg_ptr)
        mutex.release()
        for m in digest.msg:
            traffic_level = m.meta_color
            print("traffic level reached %d" % traffic_level)
            cir_gbps = cir_gbps * 1.5
            cir_kbps = cir_gbps * 1024 * 1024
            #cir_kbits = cir_kbps
            pir_kbps = 2 * cir_kbps
            #pir_kbits = pir_kbps
            p4_pd.meter_set_traffic_monitor(
                0,
                p4_pd.bytes_meter_spec_t(cir_kbps, cir_kbits, pir_kbps, pir_kbits, False)
            )
            print("updated meter thresholds to %d GBPS" % cir_gbps)
            break
    time.sleep(5)
    p4_pd.register_reset_all_bloom_meter()
    conn_mgr.complete_operations()