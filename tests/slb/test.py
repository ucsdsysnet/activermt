import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

"""class TestLoadBalancing(PrototypeTestBase):
    def runTest(self):
        #sync = active_generated_register_flags_t(read_hw_sync=1)
        #self.client.register_reset_all_heap_4(self.sess_hdl, self.dev_tgt)
        #self.client.register_reset_all_heap_1(self.sess_hdl, self.dev_tgt)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['HASH5TUPLE'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['SET_PORT'])/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['CRET'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_READ'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MBR'], arg=3)/
            ActiveProgram(opcode=self.OPCODES['HASH5TUPLE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['SET_PORT'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        pktExp[IP].ttl = 63
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 51)
        send_packet(self, 0, pkt)
        pktExp[IP].ttl = 64
        verify_packet_prefix(self, pktExp, 4, 51)"""

"""class TestLBExperiment(PrototypeTestBase):
    def runTest(self):
        sync = active_generated_register_flags_t(read_hw_sync=1)
        data = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, 255, sync)
        self.client.register_write_heap_1(self.sess_hdl, self.dev_tgt, 255, data)
        for p in range(0, 16):
            pass
            sourcePort = p + 1
        sourcePort = 8193
        print "sending packet from port %d" % sourcePort
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=sourcePort, dport=9876, chksum=0)/
            ActiveState(fid=1)/

            ActiveProgram(opcode=self.OPCODES['HASH5TUPLE'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CRET'])/

            ActiveProgram(opcode=self.OPCODES['HASH5TUPLE'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=5)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['C_ENABLE_EXEC'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['RTS'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/

            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        #pktExp[IP].ttl = 63
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 16)"""

"""class TestDummyLB(PrototypeTestBase):
    def runTest(self):
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_4(self.sess_hdl, self.dev_tgt)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, id=1)/
            ActiveProgram(opcode=self.OPCODES['HASHID'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['C_ENABLE_EXEC'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RTS'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        # for stage 1
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        verify_packet_prefix(self, pktExp, 4, 14)
        values = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f1, 1)
        self.assertEquals(values[0].f0, 255)
        # for stage 2
        pkt[ActiveState].id = 8193
        pktExp = copy.deepcopy(pkt)
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pktExp, 4, 14)
        values = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f1, 8193)
        self.assertEquals(values[0].f0, 255)
        # for stage miss
        pkt[ActiveState].id = 16385
        pktExp = copy.deepcopy(pkt)
        pktExp[IP].dst, pktExp[IP].src = pktExp[IP].src, pktExp[IP].dst
        pktExp[Ether].dst, pktExp[Ether].src = pktExp[Ether].src, pktExp[Ether].dst
        pktExp[IP].id = pktExp[IP].id + 1000
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pktExp, 0, 14)"""

class TestSLB(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES[''])/
            
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )