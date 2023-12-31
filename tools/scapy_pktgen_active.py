#!/usr/bin/python3

import os
import sys

from scapy.all import *

BASE_DIR = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))

sys.path.insert(0, os.path.join(BASE_DIR, 'include', 'python'))

from headers import *
from ap4utils import *

if len(sys.argv) < 2:
    print("Usage: %s <active_program> [iface=veth0] [fid=1]" % sys.argv[0])
    sys.exit(1)

active_program = sys.argv[1]
iface = sys.argv[2] if len(sys.argv) > 2 else "veth0"
fid = int(sys.argv[3]) if len(sys.argv) > 3 else 1

utils = AP4Utils()
utils.readConfigs()

program = utils.readActiveProgram(active_program, print_bytecode=True)

pkt = utils.constructActivePacket(fid, program, {
    'data_0'    : 0,
    'data_1'    : 1,
    'data_2'    : 2,
    'data_3'    : 0
}, preload=True, tcp_flags="S")

sendp(pkt, iface=iface, verbose=False)

print("Sent active packet to", iface)