import pdb
import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

from prototype.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *

import csv
import json
from time import time
from time import sleep

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
        opcodeList = open('config/opcodes.csv').read().strip().splitlines()
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