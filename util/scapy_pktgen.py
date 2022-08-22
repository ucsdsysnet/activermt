#!/usr/bin/python3

import os
import sys

from scapy.all import *

if "ACTIVEP4_SRC" in os.environ:
    sys.path.insert(0, os.path.join(os.environ['ACTIVEP4_SRC'], 'bfrt', 'ptf'))
else:
    sys.path.insert(0, os.path.join(os.getcwd(), 'bfrt', 'ptf'))

from headers import *

def sendPkt():
    pkt = (
        Ether(dst="00:00:00:00:00:02", src='00:00:00:00:00:01')/
        ActiveInitialHeader(fid=1, flags=0x0010)/
        ActiveMalloc(constr_lb_0=3, constr_ub_0=10, constr_ms_0=3, constr_lb_1=7, constr_ub_1=20, constr_ms_1=4)/
        IP(src="10.0.0.1", dst="10.0.0.2")/
        TCP(dport=6378)
    )

    (ans, uans) = srp(
        pkt,
        iface="veth1",
        verbose=0,
        timeout=1
    )

    if len(ans):
        print(ans)
    else:
        print(uans)

sendPkt()