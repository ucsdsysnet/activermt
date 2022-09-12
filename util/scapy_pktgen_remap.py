#!/usr/bin/python3

import os
import sys
import time
import threading

from scapy.all import *

if "ACTIVEP4_SRC" in os.environ:
    sys.path.insert(0, os.path.join(os.environ['ACTIVEP4_SRC'], 'bfrt', 'ptf'))
    sys.path.insert(0, os.path.join(os.environ['ACTIVEP4_SRC'], 'compiler'))
else:
    sys.path.insert(0, os.path.join(os.getcwd(), 'bfrt', 'ptf'))

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/site-packages' % VERSION)

from headers import *
from ap4utils import *
from ap4lib import *

import numpy as np

DEBUG = True
NUM_STAGES_IG = 10
TOTAL_STAGES = 20

FLAGS_REMAPPED = 0x0040
FLAGS_ACK = 0x0200
FLAGS_INITIATED = 0x0400

timing = {
    'start' : 0,
    'stop'  : 0
}

appCfg = {
    'fid'       : 2,
    'idx'       : list(range(0, TOTAL_STAGES)),
    'iglim'     : -1,
    'applen'    : 20,
    'mindemand' : np.ones(TOTAL_STAGES, dtype=np.uint16)
}

# assumed allocation.
allocation = {
    3   : (0, 0xFFFF),
    6   : (0, 0xFFFF),
    9   : (0, 0xFFFF)
}

programCache = {}
def buildDrainProgram(memId):
    global TOTAL_STAGES, programCache
    # TODO optimize (currently one drain packet per memory object).
    if memId in programCache:
        return programCache[memId]
    if memId == 0:
        return None
    rtsInserted = False
    i = 0
    program = []
    program.append(['MAR_LOAD_DATA_0', '$INDEX1'])
    i += 1
    while i < TOTAL_STAGES - 1:
        if i >= memId:
            program.append(['MEM_READ'])
            program.append(['DATA_1_LOAD_MBR'])
            i += 2
            break
        elif not rtsInserted:
            program.append(['RTS'])
            rtsInserted = True
            i += 1
        else:
            program.append(['NOP'])
            i += 1
    if not rtsInserted:
        program.append(['RTS'])
        rtsInserted = True
    program.append(['RETURN'])
    assert len(program) <= TOTAL_STAGES
    ap = ActiveProgram(program)
    programCache[memId] = {
        'program'   : program,
        'bytecode'  : list(ap.getByteCode())
    }
    return programCache[memId]

def sendDrainPacket(fid, memId, index):
    ap = buildDrainProgram(memId)
    pkt = (
        Ether(type=0x83b2)/
        ActiveInitialHeader(fid=fid)/
        ActiveArguments(data_0=index, data_2=memId)
    )
    for i in range(0, len(ap['program'])):
        opcode = ap['bytecode'][i * 2 + 1]
        pkt /= ActiveInstruction(opcode=opcode)
    pkt /= ActiveInstruction(opcode=0)
    pkt /= IP(src="10.0.0.1", dst="10.0.0.2", proto=0x06)
    pkt /= TCP()
    sendp(pkt, iface="veth0", verbose=False)

coreDump = {}
validity = {}

def initCoreDump():
    global coreDump, validity
    rangeStart = 0xFFFF
    rangeEnd = 0
    for stageId in allocation:
        rangeStart = allocation[stageId][0] if allocation[stageId][0] < rangeStart else rangeStart
        rangeEnd = allocation[stageId][1] if allocation[stageId][1] > rangeEnd else rangeEnd
    for stageId in allocation:
        memStart = allocation[stageId][0]
        memEnd = allocation[stageId][1]
        memSize = memEnd - memStart + 1
        if stageId not in coreDump:
            coreDump[stageId] = np.zeros(memSize, dtype=np.uint32)
            validity[stageId] = np.zeros(memSize, dtype=np.uint8)

def drain(fid):
    global allocation, coreDump, validity
    print("Initiating drain ... ")
    initCoreDump()
    for stageId in validity:
        memStart = allocation[stageId][0]
        memEnd = allocation[stageId][1]
        while not np.all(validity[stageId]):
            for idx in range(memStart, memEnd + 1):
                if not validity[stageId][idx - memStart]:
                    sendDrainPacket(fid, stageId, idx)
            time.sleep(0.1)
    print("Drain complete for FID", fid)
    
def mockDrain(fid):
    print("Waiting to drain ... ")
    time.sleep(1)
    print("Drain complete.")
    sendPkt(fid, FLAGS_REMAPPED | FLAGS_ACK)

def onPktRecv(p):
    global timing, DEBUG, coreDump, validity, allocation
    dstMac = "00:00:00:00:00:02"
    if p[Ether].dst == dstMac:
        return
    if p[Ether].type != 0x83b2:
        return
    flags = p[ActiveInitialHeader].flags
    if DEBUG:
        print( "[RECEIVED]", hex(flags), p[Ether].dst )
    isRemap = (flags & FLAGS_REMAPPED > 0)
    isAck = (flags & FLAGS_ACK > 0)
    isInit = (flags & FLAGS_INITIATED > 0)
    if isRemap:
        print("Remap flag set!")
    if isAck:
        print("Ack flag set!")
    if isInit:
        print("Init flag set!")
    # handlers
    fid = p[ActiveInitialHeader].fid
    if isRemap and not isAck and not isInit:
        sendPkt(fid, FLAGS_REMAPPED | FLAGS_INITIATED)
        th = threading.Thread(target=drain, args=(fid,))
        th.start()
    if not isRemap and not isAck and not isInit:
        if p[ActiveArguments].data_2 > 0:
            # TODO bug: may be 0th stage (unlikely).
            stageId = p[ActiveArguments].data_2
            index = p[ActiveArguments].data_0
            value = p[ActiveArguments].data_1
            print("Memory Object", stageId, index, value)
            if stageId in allocation:
                idx = index - allocation[stageId][0]
                coreDump[stageId][idx] = value
                validity[stageId][idx] = True


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
    sendp(pkt, iface="veth0", verbose=False)

def printUsage():
    print("Usage: %s <test|drain>" % sys.argv[0])
    sys.exit(1)

if len(sys.argv) < 2:
    printUsage()

th = threading.Thread(target=recvPackets, args=("veth1", "00:00:00:00:00:02", ))

fid = 1

if sys.argv[1] == 'test':
    th.start()
    initCoreDump()
    sendDrainPacket(fid, 3, 0)
    print("Press Ctrl-C to exit ... ")
    th.join()
elif sys.argv[1] == 'drain':
    th.start()
    sendPkt(fid, 0x0)
    print("Press Ctrl-C to exit ... ")
    th.join()
else:
    print("unknown command")