import atexit

p4_pd.meter_params_register()

digest = None

def unregisterMMU(self):
    global digest
    print "unregistering MMU"
    try:
        p4_pd.meter_params_digest_notify_ack(digest.msg_ptr)
        p4_pd.meter_params_digest_deregister()
    except:
        pass

atexit.register(unregisterMMU)

while True:
    try:
        digest = p4_pd.meter_params_get_digest()
        if digest.msg != []:
            msgPtr = digest.msg_ptr
            digest.msg_ptr = 0
            p4_pd.meter_params_digest_notify_ack(msgPtr)
            for m in digest.msg:
                print m
                fid = int(m.as_fid)
                color = int(m.meta_color)
            #p4_pd.register_write_bloom_meter(0, 0)
            #conn_mgr.complete_operations()
    except Exception as ex:
        template = "An exception of type {0} occurred while polling. Arguments:\n{1!r}"
        message = template.format(type(ex).__name__, ex.args)
        print message