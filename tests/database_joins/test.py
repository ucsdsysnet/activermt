import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

class TestInnerJoin(PrototypeTestBase):
    def runTest(self):
        for i in range(0, 3):
            tuple = 1536 + i
            pktLeft = (
                Ether()/
                IP(dst="10.0.0.2")/
                UDP(sport=9877, dport=9876)/
                ActiveState(fid=2)/
                ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=tuple)/
                ActiveProgram(opcode=self.OPCODES['BIT_AND_MBR_MAR'], arg=255)/
                ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['RETURN'])/
                ActiveProgram()/
                ActiveProgram(opcode=self.OPCODES['EOF'])
            )
            pktExp = copy.deepcopy(pktLeft)
            send_packet(self, 0, pktLeft)
            verify_packet_prefix(self, pktExp, 4, 46)
        for i in range(0, 3):
            tuple = 512 + i
            pktRight = (
                Ether()/
                IP(dst="10.0.0.2")/
                UDP(sport=9877, dport=9876)/
                ActiveState(fid=2)/
                ActiveProgram(opcode=self.OPCODES['MBR2_LOAD'], arg=tuple)/
                ActiveProgram(opcode=self.OPCODES['BIT_AND_MBR2_MAR'], arg=255)/
                ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=1)/
                ActiveProgram(opcode=self.OPCODES['COPY_MBR2_MBR'])/
                ActiveProgram(opcode=self.OPCODES['MEM_WRITE'], goto=1)/
                ActiveProgram(opcode=self.OPCODES['RETURN'])/
                ActiveProgram()/
                ActiveProgram(opcode=self.OPCODES['EOF'])
            )
            pktExp = copy.deepcopy(pktRight)
            send_packet(self, 0, pktRight)
            verify_packet_prefix(self, pktExp, 4, 46)
        pktDrain = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=2)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=0)/
            ActiveProgram(opcode=self.OPCODES['MAR_EQUALS'], arg=3)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['LOOP_INIT'])/
            ActiveProgram(opcode=self.OPCODES['DO'], goto=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_ADD'], arg=1)/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['MEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ACC2_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['DUPLICATE'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['MAR_EQUALS'], arg=4)/
            ActiveProgram(opcode=self.OPCODES['WHILE'])/
            ActiveProgram(goto=1)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pktDrain)
        pktCount = 0
        while True:
            result = self.dataplane.poll(port_number=4, timeout=1, exp_pkt=bytes(pktDrain)[:14])
            if isinstance(result, self.dataplane.PollFailure):
                break
            else:
                pktCount = pktCount + 1
        self.assertEquals(pktCount, 5)