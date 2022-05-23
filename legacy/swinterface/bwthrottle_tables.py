import os

clear_all()

swports = []
if 'TOFINO_MODEL' in os.environ:
    print "using port config for tofino model"
    for i in range(0, 16):
        swports.append( 4 * i )
    for i in range(16, 32):
        swports.append( 128 + 4 * i )
    swports.append(256)
    swports.append(260)
else:
    print "using port config for ASIC"
    for i in range(0, 20):
        swports.append( 188 - 4 * i )
    for i in range(20, 32):
        swports.append( 12 + 4 * (i - 20) )
    swports.append(284)
    swports.append(280)

egrset = [ 1, 3, 4, 7, 8, 11, 12, 15 ]

MIRROR_SESSIONS = len(egrset)
NUM_PORTS = MIRROR_SESSIONS

for i in range(0, MIRROR_SESSIONS):
    mirror_id = i + 1
    egrport = swports[egrset[i] - 1]
    mirror.session_create(
        mirror.MirrorSessionInfo_t(
            mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
            direction=mirror.Direction_e.PD_DIR_BOTH,
            mir_id=mirror_id,
            egr_port=egrport, egr_port_v=True,
            max_pkt_len=16384
        )
    )
    print "added mirror session %d for %d" % (mirror_id, egrport)

print "created mirror sessions"

for i in range(0, NUM_PORTS):
    port = egrset[i]
    ipaddr = "10.0.0.%d" % port
    swport = swports[port - 1]
    fwdid = i + 1
    p4_pd.forward_table_add_with_setegr(
        p4_pd.forward_match_spec_t(
            ipv4Addr_to_i32(ipaddr),
            32
        ),
        p4_pd.setegr_action_spec_t(swport, fwdid)
    )

"""for i in range(0, NUM_PORTS):
    tgt = egrset[i]
    dst = egrset[ (i + 1) % NUM_PORTS ]
    p4_pd.reroute_table_add_with_redirect(
        p4_pd.reroute_match_spec_t(
            ipv4Addr_to_i32("10.0.0.%d" % tgt)
        ),
        p4_pd.redirect_action_spec_t(
            ipv4Addr_to_i32("10.0.0.%d" % dst)
        )
    )"""

p4_pd.repeat_table_add_with_recirc(
    p4_pd.repeat_match_spec_t(
        ipv4_ttl_start=60,
        ipv4_ttl_end=hex_to_byte(255)
    ),
    1
)

conn_mgr.complete_operations()
