import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

class TestPcap(PrototypeTestBase):
    def runTest(self):
        packets = rdpcap('pcaps/debug.pcap')
        for pkt in packets:
            if UDP in pkt and int(pkt[IP].id) == 19159:
            #if UDP in pkt and str(pkt[IP].src) == "10.0.0.2":
                print "sending packet with id %d" % int(pkt[IP].id)
                send_packet(self, 0, pkt)
                pktExp = copy.deepcopy(pkt)
                verify_packet_prefix(self, pktExp, 0, 14)
                #show2(pktExp)