#!/usr/bin/python3

from scapy.all import *

pkts = rdpcap('pcaps/debug-server.pcap')

pkt_index = 9

current_idx = 0
for pkt in pkts:
    current_idx += 1
    if current_idx == pkt_index:
        sendp(pkt, iface="veth0", verbose=True)
        break