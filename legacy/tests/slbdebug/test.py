import sys
import os
import pdb
import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

from slbtest.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *

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

bind_layers(UDP, ActiveState, dport=9876)

class SLBTest(pd_base_tests.ThriftInterfaceDataPlane):
    
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["slbtest"])
        self.dpmap = {}

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
        print("Connected to Device %d with Session %d" % (self.dev, self.sess_hdl))
        self.read_maps()
        self.conn_mgr.complete_operations(self.sess_hdl)
    
    def tearDown(self):
        self.conn_mgr.complete_operations(self.sess_hdl)
        self.conn_mgr.client_cleanup(self.sess_hdl)
        print("Closed Session %d" % self.sess_hdl)
        pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)

    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1, id=1, acc=0)
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        verify_packet_prefix(self, pktExp, 4, 14)