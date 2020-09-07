import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

class TestCacheReadRequest(PrototypeTestBase):
    def runTest(self):
        sync = prototype_register_flags_t(read_hw_sync=1)
        obj = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, 1, sync)[0]

        pkt_send = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=10, flags=0x0040)/
            
            # [PASS 1] - check key, load value, update access count
            # using mem stages 5,8,11
            # address calculation
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ # compute offset based on page size
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/ # add base to offset
            # check if key exists
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=8193)/ 
            # if it exists,
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/ # load the value
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'], goto=2)/ # increment access counter
            # conditionally return if as.flag_onepass = 1

            # [PASS 2-4] - perform count-min-sketch for frequency
            # using mem stages 3,4,6,9
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 1
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/ 
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 

            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 2
            ActiveProgram(opcode=self.OPCODES['REVMIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 3
            ActiveProgram(opcode=self.OPCODES['REVMIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/

            ActiveProgram(opcode=self.OPCODES['HASHMBR'])/
            ActiveProgram(opcode=self.OPCODES['BIT_AND_MAR'], arg=8191)/ 
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # iter 4
            ActiveProgram(opcode=self.OPCODES['REVMIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=2)/ # load hot-item frequency threshold
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=2)/ # frequency crossed threshold
            ActiveProgram(opcode=self.OPCODES['MARK_IF'])/

            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        
        obj.f1 = 0x22
        obj.f0 = 8193
        self.client.register_write_heap_5(self.sess_hdl, self.dev_tgt, 0x22, obj)
        obj.f1 = 0x22
        obj.f0 = 1234
        self.client.register_write_heap_8(self.sess_hdl, self.dev_tgt, 0x22, obj)

        pkt_exp = copy.deepcopy(pkt_send)
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 0, 1)
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 0, 1)
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 0, 54)

        #data = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        #self.client.register_write_heap_3(self.sess_hdl, self.dev_tgt, 1, data)

"""class TestCacheReadResponse(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_MBR2'])/ # if the current count is lower
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=3)/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR2_MBR'])/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/ # write new min value
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'], goto=3)/ # write new min index
            ActiveProgram(opcode=self.OPCODES['RTS'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )"""