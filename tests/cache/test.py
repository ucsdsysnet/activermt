import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

"""class TestNetCache(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['HASH4K'])/
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=1024)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RTS'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['ACC2_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        for i in range(0, 11):
            send_packet(self, 0, pkt_send)
            #verify_packet_prefix(self, pkt_exp, 4, 14)"""

class TestCMS(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=8193)/ # check if the key exists
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/ # load the value
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/ # increment access counter
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/

            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_MBR2'])/ # if the current count is lower
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=3)/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR2_MBR'])/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/ # write new min value
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'], goto=3)/ # write new min index
            ActiveProgram(opcode=self.OPCODES['RTS'], goto=2)/
            # start count-min-sketch
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/ # iter 1

            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/ 
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/ # iter 2
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/ 
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/ # iter 3
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/ 
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/

            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=8193)/ # iter 4
            ActiveProgram(opcode=self.OPCODES['HASHMAR'])/ 
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['COPY_MBR_MBR2'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=10)/ # load hot-item frequency threshold
            ActiveProgram(opcode=self.OPCODES['MIN'])/
            ActiveProgram(opcode=self.OPCODES['MBR_EQUALS_ARG'], arg=10)/ # frequency crossed threshold
            ActiveProgram(opcode=self.OPCODES['CJUMP'], goto=4)/

            ActiveProgram(opcode=self.OPCODES['MARK_PROCESSED'], goto=4)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 14)