#!/usr/bin/python

import os
import sys
from scapy.all import *

try:
    pcap_file = sys.argv[1]
except:
    pcap_file = "debug.pcap"

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

data = {}
packets = rdpcap(pcap_file)
for pkt in packets:
    if ActiveState in pkt:
        pktId = pkt[ActiveState].id
        
