#!/usr/bin/python

import os
import sys
import json
from scapy.all import *

if os.getuid() !=0:
    print """
ERROR: This script requires root privileges. 
       Use 'sudo' to run it.
"""
    quit()

class ActiveState(Packet):
    name = "ActiveState"
    fields_desc = [
        ByteField("binder", 1),
        ByteField("flag", 0),
        ByteField("demand", 1),
        ShortField("fid", 0),
        ShortField("acc", 0),
        ShortField("acc2", 0),
        ByteField("done", 0),
        ShortField("id", 0)
    ]

class ActiveProgram(Packet):
    name = "ActiveProgram"
    fields_desc = [
        ByteField("flags", 0),
        ByteField("opcode", 0),
        ShortField("arg", 0),
        ByteField("goto", 0),
        ByteField("binder", 2)
    ]

bind_layers(UDP, ActiveState, dport=9876)
bind_layers(ActiveState, ActiveProgram, binder=1)
bind_layers(ActiveProgram, ActiveProgram, binder=2)

try:
    iface = sys.argv[1]
except:
    iface = "veth1"

try:
    addr = sys.argv[2]
except:
    addr = "10.0.0.2"

OPCODES = json.loads(open('../opcodes.json').read(), encoding='utf-8')

while True:
    p = (
        Ether()/
        IP(src="10.0.0.1", dst="10.0.0.2")/
        UDP(sport=9876, dport=9876, chksum=0)/
        ActiveState(fid=2)/
        ActiveProgram(opcode=OPCODES['RETURN'])/
        ActiveProgram()/
        ActiveProgram(opcode=OPCODES['EOF'])
    )
    sendp(p, iface=iface, verbose=False) 