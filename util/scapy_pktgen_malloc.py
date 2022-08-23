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

FLAGS_REQ = 0x0010
FLAGS_GET = 0x0020
NUM_STAGES_IG = 10

timing = {
    'start' : 0,
    'stop'  : 0
}

isAllocated = False

def parseAllocation(alloc):
    global NUM_STAGES_IG
    for i in range(0, NUM_STAGES_IG):
        mem_start_ig = getattr(alloc, 'start_%d' % i)
        mem_start_eg = getattr(alloc, 'start_%d' % (10 + i))
        mem_end_ig = getattr(alloc, 'end_%d' % i)
        mem_end_eg = getattr(alloc, 'end_%d' % (10 + i))
        if mem_start_ig > 0 or mem_end_ig > 0 or mem_start_eg > 0 or mem_end_eg > 0:
            print("Allocation[%d]:" % i, mem_start_ig, mem_end_ig, mem_start_eg, mem_end_eg)

def onPktRecv(p):
    global timing, isAllocated
    flags = p[ActiveInitialHeader].flags
    dstMac = "00:00:00:00:00:02"
    if p[Ether].dst == dstMac:
        return
    print( "[RECEIVED]", hex(flags), p[Ether].dst )
    if flags & 0x0008 > 0:
        if not isAllocated:
            isAllocated = True
            timing['stop'] = time.time()
        print("Allocation received")
        parseAllocation(p[ActiveAlloc])
    elif flags & 0x0004 > 0:
        print("Allocation pending")
    elif flags & 0x0020 > 0:
        print("Allocation failed")
    elif flags & 0x0010 > 0:
        print("Allocation requested")

def recvPackets(iface, dstMac):
    print("Sniffing packets on", iface)
    sniff(iface=iface, prn=onPktRecv)

def sendPkt(fid, flags):
    global FLAGS_REQ, FLAGS_GET
    if flags == FLAGS_REQ:
        pkt = (
            Ether(dst="00:00:00:00:00:02", src='00:00:00:00:00:01')/
            ActiveInitialHeader(fid=fid, flags=flags)/
            ActiveMalloc(constr_lb_0=2, constr_ub_0=9, constr_ms_0=3, constr_lb_1=6, constr_ub_1=19, constr_ms_1=4)/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            TCP(dport=6378)
        )
    else:
        pkt = (
            Ether(dst="00:00:00:00:00:02", src='00:00:00:00:00:01')/
            ActiveInitialHeader(fid=fid, flags=flags)/
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

fid = 2

th = threading.Thread(target=recvPackets, args=("veth1", "00:00:00:00:00:02", ))
th.start()

timing['start'] = time.time()
sendPkt(fid, FLAGS_REQ)
while not isAllocated:
    sendPkt(fid, FLAGS_GET)

elapsed = timing['stop'] - timing['start']
print("elapsed", elapsed)

print("Press Ctrl-C to exit ... ")
th.join()