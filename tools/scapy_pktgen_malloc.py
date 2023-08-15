#!/usr/bin/python3

import os
import sys
import time
import threading

from scapy.all import *

BASE_DIR = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))

sys.path.insert(0, os.path.join(BASE_DIR, 'include', 'python'))

from headers import *

DEBUG           = False
FLAGS_REQ       = 0x0010
FLAGS_GET       = 0x0020
NUM_STAGES_IG   = 10
IFACE           = "veth0"

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
    global timing, isAllocated, DEBUG
    flags = p[ActiveInitialHeader].flags
    dstMac = "00:00:00:00:00:02"
    if p[Ether].dst == dstMac:
        return
    if DEBUG:
        print( "[RECEIVED]", hex(flags), p[Ether].dst )
    if flags & 0x0008 > 0:
        if not isAllocated:
            isAllocated = True
            timing['stop'] = time.time()
            print("Allocation received")
            parseAllocation(p[ActiveAlloc])
    elif flags & 0x0004 > 0:
        #print("Allocation pending")
        pass
    elif flags & 0x0020 > 0:
        #print("Allocation failed")
        pass
    elif flags & 0x0010 > 0:
        #print("Allocation requested")
        pass

def recvPackets(iface):
    print("Sniffing packets on", iface)
    sniff(iface=iface, prn=onPktRecv)

def sendPkt(fid, flags):
    global FLAGS_REQ, FLAGS_GET, IFACE
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

    sendp(pkt, iface=IFACE, verbose=False)

ALLOCATION_TIMEOUT_SEC = 3
MAX_APPS = 1

th = threading.Thread(target=recvPackets, args=(IFACE, ))
th.start()

memoryFull = False
for i in range(0, MAX_APPS):
    if memoryFull:
        break
    isAllocated = False
    fid = i + 1
    timing['start'] = time.time()
    sendPkt(fid, FLAGS_GET)
    while not isAllocated:
        allocTime = time.time() - timing['start']
        if allocTime > ALLOCATION_TIMEOUT_SEC:
            print("Allocation timed out for FID", fid)
            memoryFull = True
            break
        sendPkt(fid, FLAGS_GET)
    elapsed = timing['stop'] - timing['start']
    print("FID %d Elapsed %f seconds" % (fid, elapsed))

print("Press Ctrl-C to exit ... ")
th.join()