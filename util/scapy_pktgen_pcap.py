#!/usr/bin/python3

from scapy.all import *

pkts = rdpcap('pcaps/debug-server.pcap')

i = 0
for pkt in pkts:
    i += 1
    if i < 10:
        continue
    sendp(pkt, iface="veth0", verbose=True)
    break