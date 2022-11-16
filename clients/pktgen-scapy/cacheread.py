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

DEBUG = True
NUM_STAGES_IG = 10
TOTAL_STAGES = 20

FLAGS_ARGS      = 0x8000
FLAGS_EOE       = 0x0100

def sendActivePacket(fid, bytecode, arg_0=0, arg_1=0, arg_2=0, arg_3=0, iface="veth0"):
    pkt = (
        Ether(type=0x83b2)/
        ActiveInitialHeader(fid=fid, flags=FLAGS_ARGS)/
        ActiveArguments(data_0=arg_0, data_1=arg_1, data_2=arg_2, data_3=arg_3)
    )
    for i in range(0, len(bytecode)):
        pkt /= ActiveInstruction(opcode=bytecode[i]['opcode'], goto=bytecode[i]['goto'])
    pkt /= ActiveInstruction(opcode=0)
    pkt /= IP(src="10.0.0.1", dst="10.0.0.2", proto=0x06)
    pkt /= TCP()
    sendp(pkt, iface=iface, verbose=False)

def onPktRecv(p):
    global timing, DEBUG, coreDump, validity, allocation
    # dstMac = "00:00:00:00:00:02"
    # if p[Ether].dst == dstMac:
        # return
    if p[Ether].type != 0x83b2:
        return
    flags = p[ActiveInitialHeader].flags
    if DEBUG:
        print( "[RECEIVED]", hex(flags), p[Ether].dst )

def recvPackets(iface, dstMac):
    print("Sniffing packets on", iface)
    sniff(iface=iface, prn=onPktRecv)

def printUsage():
    print("Usage: %s <program> [fid]" % sys.argv[0])
    sys.exit(1)

# main

if len(sys.argv) < 2:
    printUsage()

th = threading.Thread(target=recvPackets, args=("veth0", "00:00:00:00:00:02", ))

program = sys.argv[1]
fid = int(sys.argv[2]) if len(sys.argv) > 2 else 1
arg_0 = int(sys.argv[3]) if len(sys.argv) > 3 else 0
arg_1 = int(sys.argv[4]) if len(sys.argv) > 4 else 0
arg_2 = int(sys.argv[5]) if len(sys.argv) > 5 else 0
arg_3 = int(sys.argv[6]) if len(sys.argv) > 6 else 0

program_path = "/".join(program.split("/")[:-1])
program_name = program.split("/")[-1]

utils = AP4Utils()
utils.readConfigs()

(bytecode, args, bulk_args) = utils.readActiveProgram(program_name, base_dir=program_path)

th.start()

sendActivePacket(fid, bytecode, arg_0=arg_0, arg_1=arg_1, arg_2=arg_2, arg_3=arg_3)

th.join()