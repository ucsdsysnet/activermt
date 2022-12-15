#!/usr/bin/python3

import os
import sys

from scapy.all import *

if "ACTIVEP4_SRC" in os.environ:
    sys.path.insert(0, os.path.join(os.environ['ACTIVEP4_SRC'], 'bfrt', 'ptf'))
else:
    sys.path.insert(0, os.path.join(os.getcwd(), 'bfrt', 'ptf'))

from headers import *

FLAGS_REQALLOC = 0x0010

pkt = (
    Ether(dst="00:00:00:00:00:02", src='00:00:00:00:00:01')/
    ActiveInitialHeader(fid=254, flags=FLAGS_REQALLOC)/
    ActiveMalloc()/
    IP(src="10.0.0.1", dst="10.0.0.1")/
    UDP(dport=6378)
)

iface = sys.argv[1] if len(sys.argv) > 1 else "veth0"

sendp(pkt, iface=iface, verbose=False)

print("Sent malloc reset packet to", iface)