#!/usr/bin/python3

import os
import sys
import time
import threading

from scapy.all import *

if "ACTIVEP4_SRC" in os.environ:
    sys.path.insert(0, os.path.join(os.environ['ACTIVEP4_SRC'], 'bfrt', 'ptf'))
else:
    sys.path.insert(0, os.path.join(os.getcwd(), 'bfrt', 'ptf'))

from headers import *

DEBUG = True
NUM_STAGES_IG = 10

FLAGS_REMAPPED = 0x0040
FLAGS_ACK = 0x0200
FLAGS_INITIATED = 0x0400

timing = {
    'start' : 0,
    'stop'  : 0
}

def onPktRecv(p):
    global timing, DEBUG
    flags = p[ActiveInitialHeader].flags
    """dstMac = "00:00:00:00:00:02"
    if p[Ether].dst == dstMac:
        return"""
    if DEBUG:
        print( "[RECEIVED]", hex(flags), p[Ether].dst )
    if flags & FLAGS_REMAPPED > 0:
        print("Remap flag set!")
    if flags & FLAGS_ACK > 0:
        print("Ack flag set!")
    if flags & FLAGS_INITIATED > 0:
        print("Init flag set!")

def recvPackets(iface, dstMac):
    print("Sniffing packets on", iface)
    sniff(iface=iface, prn=onPktRecv)

def sendPkt(fid, flags):
    pkt = (
        Ether(dst="00:00:00:00:00:02", src='00:00:00:00:00:01')/
        ActiveInitialHeader(fid=fid, flags=flags)/
        ActiveArguments()/
        ActiveInstruction(opcode=2)/
        ActiveInstruction(opcode=0)/
        IP(src="10.0.0.1", dst="10.0.0.2")/
        TCP(dport=6378)
    )

    """(ans, uans) = srp(
        pkt,
        iface="veth0",
        verbose=0,
        timeout=1
    )
    if len(ans):
        print(ans)
    else:
        print(uans)"""

    sendp(pkt, iface="veth0", verbose=False)

th = threading.Thread(target=recvPackets, args=("veth1", "00:00:00:00:00:02", ))
th.start()

fid = 1

sendPkt(fid, 0x0)

print("Press Ctrl-C to exit ... ")
th.join()