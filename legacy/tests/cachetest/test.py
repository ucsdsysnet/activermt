import pdb
import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

from cachetest.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *

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

bind_layers(UDP, ActiveState, dport=9876)

class CacheTestBase(pd_base_tests.ThriftInterfaceDataPlane):
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["cachetest"])
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
        print("Connected to Device %d with Session %d" % (self.dev, self.sess_hdl))
        self.read_maps()
        self.conn_mgr.complete_operations(self.sess_hdl)
    
    def tearDown(self):
        self.conn_mgr.complete_operations(self.sess_hdl)
        self.conn_mgr.client_cleanup(self.sess_hdl)
        print("Closed Session %d" % self.sess_hdl)
        pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)

"""class TestCache(CacheTestBase):
    def runTest(self):

        CACHE_READ=0
        CACHE_WRITE=1
        KEY=1

        self.client.register_reset_all_cache_key(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_cache_value(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_cms_1(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_cms_2(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_cms_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_cms_4(self.sess_hdl, self.dev_tgt)

        sleep(0.5)

        # write packet

        pktSend = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, acc2=CACHE_WRITE, acc=1, id=0, freq=KEY)
        )
        pktExp = copy.deepcopy(pktSend)
        pktExp[ActiveState].flags = 256
        send_packet(self, 0, pktSend)
        verify_packet(self, pktExp, 4)

        sleep(0.5)

        # read packet

        pktSend = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, acc2=CACHE_READ, acc=0, id=0, freq=KEY)
        )
        pktExp = copy.deepcopy(pktSend)
        pktExp[ActiveState].flags = 256
        pktExp[ActiveState].acc2 = 6
        pktExp[Ether].dst = pktExp[Ether].src
        pktExp[IP].dst = pktExp[IP].src
        del pktExp[UDP].chksum
        send_packet(self, 0, pktSend)
        verify_packet(self, pktExp, 0)"""

class TestPcap(CacheTestBase):
    def runTest(self):
        packets = rdpcap('tests/cachetest/debug-01.pcap')
        for pkt in packets:
            if UDP in pkt and int(pkt[IP].id) != 19213:
                continue
            #print "sending packet with id %d" % int(pkt[IP].id)
            send_packet(self, 0, pkt)
            pktExp = copy.deepcopy(pkt)
            verify_packet_prefix(self, pktExp, 0, 14)
            #show2(pktExp)
            break