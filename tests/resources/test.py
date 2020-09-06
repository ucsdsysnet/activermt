import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

class TestMemoryQuotas(PrototypeTestBase):
    def runTest(self):
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        pkt = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=3)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pkt, 4, 14)
        values = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f0, 0)
        self.assertEquals(values[0].f1, 0)
        pkt[ActiveState].fid = 2
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pkt, 4, 14)
        values = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f0, 255)
        self.assertEquals(values[0].f1, 1)

class TestQuotasCycle(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=3, demand=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 63
        pkt_exp[ActiveState].acc = 4
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 51)

class TestQuotasAbort(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=3, demand=4)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 64
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 8, 51)

class TestCycleQuotas(PrototypeTestBase):
    def runTest(self):
        num_iter = 4
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=num_iter)/
            ActiveProgram(opcode=self.OPCODES['LOOP_INIT'])/
            ActiveProgram(opcode=self.OPCODES['DO'], goto=1)/ 
            ActiveProgram(opcode=self.OPCODES['MBR_SUBTRACT'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['WHILE'])/
            ActiveProgram(goto=1)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 64 - num_iter
        pkt_exp[IP].id = pkt_exp[IP].id + num_iter * 1000
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 23)