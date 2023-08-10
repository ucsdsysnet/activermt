import os
import sys
import copy

BASE_DIR = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..', '..'))

sys.path.insert(0, os.path.join(BASE_DIR, 'include', 'python'))

from testbase import *

class NOP(ActiveRMTTest):

    def runTest(self):

        self.installNOPRuntime()

        fid = 1

        program = AP4Source(os.path.join(os.path.dirname(os.path.realpath(__file__)), 'nop.ap4')).getProgram()
        print("Using program:")
        program.printProgram()
        
        src_ip, src_port = self.getIP(0)
        dst_ip, dst_port = self.getIP(1)

        pkt_ig = self.constructActivePacket(fid, program.program, src=src_ip, dst=dst_ip)
        pkt_eg = self.constructActivePacket(fid, [], src=src_ip, dst=dst_ip)
        pkt_eg[ActiveInitialHeader].flags |= 0x0100
        
        send_packet(self, src_port, pkt_ig)
        verify_packet(self, pkt_eg, dst_port)