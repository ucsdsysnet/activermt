import pdb
import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

from bwthrottle.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *

class BWThrottleTestBase(pd_base_tests.ThriftInterfaceDataPlane):

    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["bwthrottle"])

    def setUp(self):
        pd_base_tests.ThriftInterfaceDataPlane.setUp(self)
        self.sess_hdl = self.conn_mgr.client_init()
        self.dev      = 0
        self.dev_tgt  = DevTarget_t(self.dev, hex_to_i16(0xFFFF))
        print "Connected to Device %d with Session %d" % (self.dev, self.sess_hdl)
    
    def tearDown(self):
        self.conn_mgr.complete_operations(self.sess_hdl)
        self.conn_mgr.client_cleanup(self.sess_hdl)
        print "Closed Session %d" % self.sess_hdl
        pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)

class BWThrottleTest(BWThrottleTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.1", ttl=1, chksum=0)
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 0
        pkt_exp[IP].chksum = 0
        send_packet(self, 0, pkt_send)
        verify_packet(self, pkt_exp, 0)