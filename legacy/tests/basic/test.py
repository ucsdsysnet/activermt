import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

class TestBasic(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=10)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        verify_packet_prefix(self, pktExp, 4, 14)

"""class TestMemoryWrite(PrototypeTestBase):
    def runTest(self):
        sync = active_generated_register_flags_t(read_hw_sync=1)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=10)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=11)/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        verify_packet_prefix(self, pktExp, 4, 14)
        data = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 8193, sync)
        self.assertEquals(data[0].f0, 11)
        self.assertEquals(data[0].f1, 8193)

class TestRMW(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(demand=1, fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 63
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_2(self.sess_hdl, self.dev_tgt)
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 46)
        data = self.client.register_read_heap_2(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0], 1)

class TestConditional(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState()/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2)/ 
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['UJUMP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=2, goto=2)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[ActiveState].acc = 1
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 46)
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState()/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2)/ 
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['UJUMP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MBR_ADD'], arg=2, goto=2)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[ActiveState].acc = 3
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 46)

class TestLoop(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState()/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=3)/
            ActiveProgram(opcode=self.OPCODES['LOOP_INIT'])/
            ActiveProgram(opcode=self.OPCODES['DO'], goto=1)/ 
            ActiveProgram(opcode=self.OPCODES['MBR_SUBTRACT'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['WHILE'])/
            ActiveProgram(goto=1)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[ActiveState].acc = 0
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 46)

class TestLoopConditional(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['MBR2_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=1)/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['LOOP_INIT'])/
            ActiveProgram(opcode=self.OPCODES['DO'], goto=1)/ 
            ActiveProgram(opcode=self.OPCODES['MBR2_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MBR2_EQUALS'], arg=2)/
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=5)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_EQUALS'], arg=3)/
            ActiveProgram(opcode=self.OPCODES['WHILE'])/
            ActiveProgram(goto=1)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        pkt_exp[IP].ttl = 60
        pkt_exp[ActiveState].acc = 5
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 51)

class TestRTS(PrototypeTestBase):
    def runTest(self):
        pktSend = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, flag=0)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=1)/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'], goto=1)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktSend)
        pktExp[Ether].dst = pktExp[Ether].src
        pktExp[IP].dst = "10.0.0.1"
        pktExp[IP].id = pktExp[IP].id + 1
        pktExp[ActiveState].acc = 1
        pktExp[ActiveState].flag = 0
        send_packet(self, 0, pktSend)
        verify_packet_prefix(self, pktExp, 0, 51)
        pktSend = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, flag=0)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktSend)
        send_packet(self, 0, pktSend)
        verify_packet_prefix(self, pktExp, 4, 51)

class TestDuplication(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, demand=9)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=3)/
            ActiveProgram(opcode=self.OPCODES['LOOP_INIT'])/
            ActiveProgram(opcode=self.OPCODES['DO'], goto=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_SUBTRACT'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['DUPLICATE'])/
            ActiveProgram(opcode=self.OPCODES['WHILE'])/
            ActiveProgram(goto=1)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt_send)
        pktCount = 0
        while True:
            result = self.dataplane.poll(port_number=4, timeout=1, exp_pkt=bytes(pkt_send)[:14])
            if isinstance(result, self.dataplane.PollFailure):
                break
            else:
                pktCount = pktCount + 1
        self.assertEquals(pktCount, 4)

class TestNonDuplication(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, demand=9)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=3)/
            ActiveProgram(opcode=self.OPCODES['LOOP_INIT'])/
            ActiveProgram(opcode=self.OPCODES['DO'], goto=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_SUBTRACT'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['WHILE'])/
            ActiveProgram(goto=1)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt_send)
        pktCount = 0
        while True:
            result = self.dataplane.poll(port_number=4, timeout=1, exp_pkt=bytes(pkt_send)[:14])
            if isinstance(result, self.dataplane.PollFailure):
                break
            else:
                pktCount = pktCount + 1
        self.assertEquals(pktCount, 1)"""
