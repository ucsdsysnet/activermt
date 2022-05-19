import pdb
import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

from prototype.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *

import csv
import json
import sys
import os
import time

sys.path.insert(1, os.getcwd())

class ActiveState(Packet):
    name = "ActiveState"
    fields_desc = [
        ShortField("flags", 0),
        ShortField("fid", 0),
        ShortField("acc", 0),
        ShortField("acc2", 0),
        ShortField("id", 0),
        ShortField("freq", 0)
    ]

class ActiveProgram(Packet):
    name = "ActiveProgram"
    fields_desc = [
        ByteField("goto", 0), # also has flags
        ByteField("opcode", 0),
        ShortField("arg", 0)
    ]

class SkipBlock(Packet):
    name = "Padding"
    fields_desc = [
        FieldLenField("len", None, length_of="data"),
        StrLenField("data", "", length_from=lambda pkt:pkt.len)
    ]

bind_layers(UDP, ActiveState, dport=9876)

class PrototypeTestBase(pd_base_tests.ThriftInterfaceDataPlane):
    
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["prototype"])
        self.dpmap = {}
        self.OPCODES = {}
        opcodeList = open('%s/config/opcodes.csv' % os.getcwd()).read().strip().splitlines()
        for id in range(0, len(opcodeList)):
            self.OPCODES[ opcodeList[id] ] = id + 1

    def read_maps(self):
        with open('/tmp/dp_mappings_identity.csv', 'r') as f:
            lines = f.read().strip().splitlines()
            for l in lines:
                row = l.split(",")
                self.dpmap[int(row[0])] = int(row[1])
            f.close()

    def setUp(self):
        pd_base_tests.ThriftInterfaceDataPlane.setUp(self)
        self.sess_hdl = self.conn_mgr.client_init()
        self.dev      = 0
        self.dev_tgt  = DevTarget_t(self.dev, hex_to_i16(0xFFFF))
        print "Connected to Device %d with Session %d" % (self.dev, self.sess_hdl)
        self.read_maps()
        self.conn_mgr.complete_operations(self.sess_hdl)
        """methods = dir(self.client)
        with open('client_methods.txt', 'w') as out:
            out.write("\n".join(methods))
            out.close()"""
    
    def tearDown(self):
        self.conn_mgr.complete_operations(self.sess_hdl)
        self.conn_mgr.client_cleanup(self.sess_hdl)
        print "Closed Session %d" % self.sess_hdl
        pd_base_tests.ThriftInterfaceDataPlane.tearDown(self) 

"""class TestBGTRaffic(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(dport=1234, chksum=0)
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].len = 0xffb0
        pkt_exp[IP].ttl = 62
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 24)"""

class TestCacheTraffic(PrototypeTestBase):
    def runTest(self):
        sync = prototype_register_flags_t(read_hw_sync=1)
        obj = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, 1, sync)[0]

        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=10, flags=0x0040, acc2=8193)/
            
            # 1: basic functionality
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/ # address calculation
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/ # check if key exists
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2)/ # if it exists
            ActiveProgram(opcode=self.OPCODES['RTSI'])/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/ # load the value
            ActiveProgram(opcode=self.OPCODES['ACC2_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'], goto=2)/ # increment access counter
            ActiveProgram(opcode=self.OPCODES['LOAD_FROM_ACC'])/ # if there's enough cycles to execute remaining
            ActiveProgram(opcode=self.OPCODES['MBR2_LOAD'], arg=5)/
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=5)/
            ActiveProgram(opcode=self.OPCODES['CRET'])/ # don't continue execution and preserve bw
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/

            # rest: count-min-sketch for frequency monitoring
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/ # using mem stages 
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 1
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/ 
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 

            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 2
            ActiveProgram(opcode=self.OPCODES['REVMIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 3
            ActiveProgram(opcode=self.OPCODES['REVMIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/

            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 4
            ActiveProgram(opcode=self.OPCODES['REVMIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=2)/ # load hot-item frequency threshold
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=2)/ # frequency crossed threshold
            ActiveProgram(opcode=self.OPCODES['MARK_IF'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/

            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )

        # resource manager sets recirculation quotas
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 61
        pkt_exp[IP].id = pkt_exp[IP].id + 3 * 1000
        pkt_exp[Ether].src,pkt_exp[Ether].dst = pkt_exp[Ether].dst,pkt_exp[Ether].src
        #pkt_exp[IP].len = 192 # = 248 - 4 * 14
        pkt_exp[IP].len = 48 # = 248 - 4 * 50
        pkt_exp[ActiveState].acc2 = 100
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 0, 24)