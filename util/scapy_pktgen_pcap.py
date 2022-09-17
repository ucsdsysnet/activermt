#!/usr/bin/python3

from scapy.all import *

pkts = rdpcap('pcaps/pktgen.pcap')

for pkt in pkts:
    sendp(pkt, iface="veth0", verbose=True)
    break