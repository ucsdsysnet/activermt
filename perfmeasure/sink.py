#!/usr/bin/python

import os
import sys
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
        ShortField("acc2", 0)
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
    iface=sys.argv[1]
except:
    iface="enp59s0"

"""def handle_pkt(pkt):
    now = time.time()
    if UDP in pkt and ActiveState in pkt:
        if pkt[ActiveState].flag == 1:
            if pkt[ActiveState].acc > 0 and pkt[ActiveState].acc2 > 0:
                print "joined tuple received:  (%d,%d)" % (pkt[ActiveState].acc, pkt[ActiveState].acc2)"""

def handle_pkt(pkt):
    if UDP in pkt and ActiveState in pkt and pkt[IP].dst == "10.0.0.2":
        a = pkt[ActiveState]
        print "%d,%d,%d,%d,%d,%d" % (a.binder, a.flag, a.demand, a.fid, a.acc, a.acc2)
        pkt[Ether].src, pkt[Ether].dst = pkt[Ether].dst, pkt[Ether].src
        pkt[IP].src, pkt[IP].dst = pkt[IP].dst, pkt[IP].src
        pkt[IP].id = pkt[IP].id + 1
        sendp(pkt, iface=iface)

print "Receiver sniffing on ", iface
print "Press Ctrl-C to stop..."
sniff(iface = iface, prn = lambda x: handle_pkt(x))

