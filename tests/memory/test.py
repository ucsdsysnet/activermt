import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

class TestChaining(PrototypeTestBase):
    def runTest(self):
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_4(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_5(self.sess_hdl, self.dev_tgt)
        # 1st attempt
        pktChain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=11)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pktChain)
        verify_packet_prefix(self, pktChain, 4, 51)
        data = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 11)
        self.assertEquals(data[0].f1, 8193)
        data = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 0)
        self.assertEquals(data[0].f1, 0)
        data = self.client.register_read_heap_5(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 0)
        self.assertEquals(data[0].f1, 0)
        # 2nd attempt
        pktChain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=16385)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=12)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pktChain)
        verify_packet_prefix(self, pktChain, 4, 51)
        data = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 11)
        self.assertEquals(data[0].f1, 8193)
        data = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 12)
        self.assertEquals(data[0].f1, 16385)
        data = self.client.register_read_heap_5(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 0)
        self.assertEquals(data[0].f1, 0)
        # 3rd attempt
        pktChain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=24577)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=13)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pktChain)
        verify_packet_prefix(self, pktChain, 4, 51)
        data = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 11)
        self.assertEquals(data[0].f1, 8193)
        data = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 12)
        self.assertEquals(data[0].f1, 16385)
        data = self.client.register_read_heap_5(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0].f0, 13)
        self.assertEquals(data[0].f1, 24577)
        # reads 1
        pktChain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktChain)
        pktExp[ActiveState].acc = 11
        send_packet(self, 0, pktChain)
        verify_packet_prefix(self, pktExp, 4, 51)
        # reads 2
        pktChain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=16385)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktChain)
        pktExp[ActiveState].acc = 12
        send_packet(self, 0, pktChain)
        verify_packet_prefix(self, pktExp, 4, 51)
        # reads 3
        pktChain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=24577)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktChain)
        pktExp[ActiveState].acc = 13
        send_packet(self, 0, pktChain)
        verify_packet_prefix(self, pktExp, 4, 51)

class TestMemoryAllocation(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt_send)
        pktExp = copy.deepcopy(pkt_send)
        pktExp[Ether].dst, pktExp[Ether].src = pktExp[Ether].src, pktExp[Ether].dst
        verify_packet_prefix(self, pktExp, 0, 14)
        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1, flags=0x0020)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pkt_send)
        pktExp[Ether].dst, pktExp[Ether].src = pktExp[Ether].src, pktExp[Ether].dst
        pktExp[IP].dst, pktExp[IP].src = pktExp[IP].src, pktExp[IP].dst
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pktExp, 0, 14)
        sleep(1)
        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_send, 4, 14)

class TestMultipleAllocation(PrototypeTestBase):
    def runTest(self):
        for fid in range(1, 9):
            pkt_send = (
                Ether()/
                IP(src="10.0.0.1", dst="10.0.0.2")/
                UDP(sport=9877, dport=9876)/
                ActiveState(fid=fid, flags=0x0020)/
                ActiveProgram(opcode=self.OPCODES['RETURN'])/
                ActiveProgram()/
                ActiveProgram(opcode=self.OPCODES['EOF'])
            )
            pktExp = copy.deepcopy(pkt_send)
            pktExp[Ether].dst, pktExp[Ether].src = pktExp[Ether].src, pktExp[Ether].dst
            pktExp[IP].dst, pktExp[IP].src = pktExp[IP].src, pktExp[IP].dst
            send_packet(self, 0, pkt_send)
            verify_packet_prefix(self, pktExp, 0, 14)

class TestMemoryFault(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        del pktExp[Ether].src
        del pktExp[Ether].dst
        del pktExp[IP].src
        del pktExp[IP].dst
        pktExp[ActiveState].flags = 0x0080
        verify_packet(self, pktExp, 0)
