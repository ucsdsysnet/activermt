import sys
import os

sys.path.insert(1, os.getcwd())

from tests.ptf_base import *

# Cache Tests

"""class TestCacheStages(PrototypeTestBase):
    def runTest(self):
        for stage in range(0, 11):
            key = (stage << 8) + 1
            value = stage + 1
            pktWrite = (
                Ether()/
                IP(src="10.0.0.1", dst="10.0.0.2")/
                UDP(sport=9877, dport=9876, chksum=0)/
                ActiveState(fid=1)/
                ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=key)/
                ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=value)/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
                ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
                ActiveProgram(opcode=self.OPCODES['RETURN'])/
                ActiveProgram()/
                ActiveProgram(opcode=self.OPCODES['EOF'])
            )
            pktExp = copy.deepcopy(pktWrite)
            pktExp[IP].ttl = 63
            print "sending write packet #%d" % value
            send_packet(self, 0, pktWrite)
            verify_packet_prefix(self, pktExp, 4, 51)
        for stage in range(0, 11):
            key = (stage << 8) + 1
            value = stage + 1
            pktRead = (
                Ether()/
                IP(src="10.0.0.1", dst="10.0.0.2")/
                UDP(sport=9877, dport=9876, chksum=0)/
                ActiveState(fid=1)/
                ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=key)/
                ActiveProgram(opcode=self.OPCODES['NOP'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
                ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
                ActiveProgram(opcode=self.OPCODES['RTS'])/
                ActiveProgram(opcode=self.OPCODES['ACC_LOAD'], goto=2)/
                ActiveProgram(opcode=self.OPCODES['RETURN'])/
                ActiveProgram()/
                ActiveProgram(opcode=self.OPCODES['EOF'])
            )
            pktExp = copy.deepcopy(pktRead)
            pktExp[IP].dst = "10.0.0.1"
            pktExp[Ether].dst = pktExp[Ether].src
            pktExp[IP].ttl = 63
            pktExp[IP].id = pktExp[IP].id + 1
            pktExp[ActiveState].acc = value
            print "sending read packet #%d" % value
            send_packet(self, 0, pktRead)
            verify_packet_prefix(self, pktExp, 0, 51)"""

"""class TestCaching(PrototypeTestBase):
    def runTest(self):
        print "testing write #1"
        pktWrite = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
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
        send_packet(self, 0, pktWrite)
        pktExp = copy.deepcopy(pktWrite)
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 51)
        print "testing write #2"
        pktWrite = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
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
        send_packet(self, 0, pktWrite)
        pktExp = copy.deepcopy(pktWrite)
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 51)
        print "testing read #1"
        pktRead = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=24577)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktRead)
        pktExp[ActiveState].done = 1
        send_packet(self, 0, pktRead)
        verify_packet_prefix(self, pktExp, 4, 51)
        print "testing read #2"
        pktRead = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pktRead)
        pktExp[Ether].dst = pktExp[Ether].src
        pktExp[IP].dst = "10.0.0.1"
        pktExp[IP].id = pktExp[IP].id + 1
        pktExp[ActiveState].done = 1
        pktExp[ActiveState].acc = 11
        send_packet(self, 0, pktRead)
        verify_packet_prefix(self, pktExp, 0, 51)"""

"""class TestCacheWrite(PrototypeTestBase):
    def runTest(self):
        pktWrite = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=24575)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=14)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pktWrite)
        pktExp = copy.deepcopy(pktWrite)
        pktExp[Ether].dst, pktExp[Ether].src = pktExp[Ether].src, pktExp[Ether].dst
        pktExp[IP].dst, pktExp[IP].src = pktExp[IP].src, pktExp[IP].dst
        pktExp[IP].ttl = 63
        pktExp[IP].id = pktExp[IP].id + 1000
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 0, 51)"""

"""class TestPacketRead(PrototypeTestBase):
    def runTest(self):
        pktRead = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, acc=16385)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=16385)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['CJUMPI'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['ACC2_LOAD'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pktRead)
        pktExp = copy.deepcopy(pktRead)
        pktExp[Ether].dst, pktExp[Ether].src = pktExp[Ether].src, pktExp[Ether].dst
        pktExp[IP].dst, pktExp[IP].src = pktExp[IP].src, pktExp[IP].dst
        pktExp[IP].ttl = 63
        pktExp[IP].id = pktExp[IP].id + 1000
        pktExp[ActiveState].acc = 12
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 14)"""

"""class TestCounter(PrototypeTestBase):
    def runTest(self):
        regIndex = 1
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_2(self.sess_hdl, self.dev_tgt)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=regIndex)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].acc = 0
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 51)
        regValues = self.client.register_read_heap_2(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertEquals(regValues[0], 1)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=regIndex)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp[ActiveState].acc = 1
        verify_packet_prefix(self, pktExp, 4, 51)
        regValues = self.client.register_read_heap_2(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertEquals(regValues[0], 2)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=regIndex)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_READ'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp[ActiveState].acc = 2
        verify_packet_prefix(self, pktExp, 4, 51)
        regValues = self.client.register_read_heap_2(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertEquals(regValues[0], 2)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=regIndex)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].acc = 0
        pktExp[ActiveState].done = 1
        verify_packet_prefix(self, pktExp, 4, 51)
        regValues = self.client.register_read_heap_2(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertEquals(regValues[0], 3)"""

"""class TestConditionalCount(PrototypeTestBase):
    def runTest(self):
        regIndex = 1
        sync = active_generated_register_flags_t(read_hw_sync=1)
        heaps = [
            self.client.register_write_heap_3,
            self.client.register_write_heap_5,
            self.client.register_write_heap_7
        ]
        counters = [
            self.client.register_read_heap_4,
            self.client.register_read_heap_6,
            self.client.register_read_heap_8
        ]
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_4(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_5(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_6(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_7(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_8(self.sess_hdl, self.dev_tgt)
        dRegValues = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, regIndex, sync)
        updateValue = dRegValues[0]
        for k in range(0, len(heaps)):
            updateValue.f0 = 255 - k
            updateValue.f1 = (1 << (12 + k)) + regIndex if k > 0 else regIndex
            print "writing heap at step %d with object <%d, %d>" % (k + 1, updateValue.f0, updateValue.f1)
            heaps[k](self.sess_hdl, self.dev_tgt, regIndex, updateValue)
        for k in range(0, len(heaps)):
            for rep in range(0, k + 1):
                key = (1 << (12 + k)) + regIndex if k > 0 else regIndex
                pkt = (
                    Ether()/
                    IP(src="10.0.0.1", dst="10.0.0.2")/
                    UDP(sport=9877, dport=9876, chksum=0)/
                    ActiveState(fid=1)/
                    ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=key)/
                    ActiveProgram(opcode=self.OPCODES['NOP'])/
                    ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                    ActiveProgram(opcode=self.OPCODES['CCOUNTR'])/
                    ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                    ActiveProgram(opcode=self.OPCODES['CCOUNTR'])/
                    ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
                    ActiveProgram(opcode=self.OPCODES['CCOUNTR'])/
                    ActiveProgram(opcode=self.OPCODES['RETURN'])/
                    ActiveProgram()/
                    ActiveProgram(opcode=self.OPCODES['EOF'])
                )
                send_packet(self, 0, pkt)
                pktExp = copy.deepcopy(pkt)
                pktExp[ActiveState].done = 1
                verify_packet_prefix(self, pktExp, 4, 51)
            regValues = counters[k](self.sess_hdl, self.dev_tgt, regIndex, sync)
            self.assertEquals(regValues[0].f1, k + 1)"""

"""class TestLBLRU(PrototypeTestBase):
    def runTest(self):
        regIndex = 1
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_4(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_6(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_7(self.sess_hdl, self.dev_tgt)
        defaults = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)[0]
        data = defaults
        data.f0 = 255
        data.f1 = 1
        self.client.register_write_heap_3(self.sess_hdl, self.dev_tgt, regIndex, data)
        data.f0 = 255
        data.f1 = 8193
        self.client.register_write_heap_6(self.sess_hdl, self.dev_tgt, regIndex, data)
        writeCounters = [
            self.client.register_write_heap_4,
            self.client.register_write_heap_7
        ]
        updateValue = defaults
        for k in range(0, len(writeCounters)):
            updateValue.f0 = 0
            updateValue.f1 = 2 - k
            writeCounters[k](self.sess_hdl, self.dev_tgt, regIndex, updateValue)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, id=16385)/
            ActiveProgram(opcode=self.OPCODES['HASHID'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=4)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_RMW'])/
            ActiveProgram(opcode=self.OPCODES['C_ENABLE_EXEC'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['UJUMP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'], goto=2)/
            # LRU
            # phase 1, reads the min counts
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255, flags=3)/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_MINREAD'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_MINREAD'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram()/
            # phase 2, mark the stage for LRU
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['UPDATE_LRUTGT'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['UPDATE_LRUTGT'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram()/
            # phase 3, purge memory at the marked stage
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=250)/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        # send complete packet
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pkt, 4, 14)
        # verify correct mem location purged
        values = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertNotEquals(values[0].f0, 250)
        values = self.client.register_read_heap_7(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertEquals(values[0].f0, 250)"""

"""class TestDataplaneLRU(PrototypeTestBase):
    def runTest(self):
        # start LRU
        regIndex = 1
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_6(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_9(self.sess_hdl, self.dev_tgt)
        writeCounters = [
            self.client.register_write_heap_3,
            self.client.register_write_heap_6,
            self.client.register_write_heap_9
        ]
        dRegValues = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, regIndex, sync)
        updateValue = dRegValues[0]
        for k in range(0, len(writeCounters)):
            updateValue.f0 = 0
            updateValue.f1 = 3 - k
            writeCounters[k](self.sess_hdl, self.dev_tgt, regIndex, updateValue)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            # phase 1, reads the min counts
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=regIndex)/
            ActiveProgram(opcode=self.OPCODES['COUNTER_MINREAD'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_MINREAD'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['COUNTER_MINREAD'])/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram()/
            # phase 2, mark the stage for LRU
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['UPDATE_LRUTGT'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['UPDATE_LRUTGT'])/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['CMEM_READ'])/
            ActiveProgram(opcode=self.OPCODES['UPDATE_LRUTGT'])/
            ActiveProgram()/
            # phase 3, purge memory at the marked stage
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=255)/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['LRU_PURGE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pkt, 4, 14)
        values = self.client.register_read_heap_2(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertNotEquals(values[0].f0, 255)
        values = self.client.register_read_heap_5(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertNotEquals(values[0].f0, 255)
        values = self.client.register_read_heap_8(self.sess_hdl, self.dev_tgt, regIndex, sync)
        self.assertEquals(values[0].f0, 255)"""

"""class TestAuxCode(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, flag=8)/
            Raw(RandString(size=48))/
            ActiveProgram(opcode=self.OPCODES['NOP'], flags=3)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        print "packet of size %d bytes sent" % (len(pkt))
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].done = 1
        pktExp[ActiveState].flag = 0
        verify_packet_prefix(self, pktExp, 4, 51)"""

"""class TestAuxBranch(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            
            ActiveProgram(opcode=self.OPCODES['GOTO_AUX'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])/

            Raw(RandString(size=200))/

            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=5)/
            ActiveProgram(opcode=self.OPCODES['ACC_LOAD'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        print "packet of size %d bytes sent" % (len(pkt))
        send_packet(self, 0, pkt)
        pktExp = copy.deepcopy(pkt)
        pktExp[IP].ttl = 63
        pktExp[ActiveState].done = 1
        pktExp[ActiveState].acc = 5
        verify_packet_prefix(self, pktExp, 4, 51)"""

"""class TestLRU(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=8193)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=12)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].done = 1
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pktExp, 4, 51)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=16385)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=13)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].done = 1
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pktExp, 4, 51)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=24577)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=14)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['C_ENABLE_EXEC'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['LRU'])/
            ActiveProgram(opcode=self.OPCODES['NOP'], goto=2)/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].done = 1
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pktExp, 4, 51)
        sleep(5)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=24577)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=14)/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['CMEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pktExp = copy.deepcopy(pkt)
        pktExp[ActiveState].done = 1
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pktExp, 4, 51)"""

"""class TestUpdatedParsing(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['RTS'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        pktExp = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['EOF'], flags=1)
        )
        pktExp[ActiveState].done = 1
        pktExp[Ether].src, pktExp[Ether].dst = pktExp[Ether].dst, pktExp[Ether].src
        pktExp[IP].src, pktExp[IP].dst = pktExp[IP].dst, pktExp[IP].src
        pktExp[IP].id = pktExp[IP].id + 1000
        del pktExp[IP].chksum
        verify_packet(self, pktExp, 0)"""

"""class TestDigest(PrototypeTestBase):
    def runTest(self):
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, flag=6, id=8193)/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)"""

"""class TestDataplaneGC(PrototypeTestBase):
    def runTest(self):
        sync = active_generated_register_flags_t(read_hw_sync=1)
        self.client.register_reset_all_heap_3(self.sess_hdl, self.dev_tgt)
        self.client.register_reset_all_heap_4(self.sess_hdl, self.dev_tgt)
        obj = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)[0]
        obj.f1 = 1
        obj.f0 = 255
        self.client.register_write_heap_3(self.sess_hdl, self.dev_tgt, 1, obj)
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, id=8193)/
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
        send_packet(self, 0, pkt)
        verify_packet_prefix(self, pkt, 4, 14)
        values = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f1, 8193)
        self.assertEquals(values[0].f0, 255)
        # clean
        pkt = (
            Ether()/
            IP(src="10.0.0.1", dst="10.0.0.2")/
            UDP(sport=9877, dport=9876, chksum=0)/
            ActiveState(fid=1, id=8193)/
            ActiveProgram(opcode=self.OPCODES['HASHID'])/
            ActiveProgram(opcode=self.OPCODES['NOP'])/
            ActiveProgram(opcode=self.OPCODES['MEM_RST'])/
            ActiveProgram(opcode=self.OPCODES['MEM_RST'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        send_packet(self, 0, pkt)
        verify_no_packet(self, pkt, 4)
        values = self.client.register_read_heap_3(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f0, 255)
        self.assertEquals(values[0].f1, 1)
        values = self.client.register_read_heap_4(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(values[0].f0, 0)
        self.assertEquals(values[0].f1, 0)"""

"""class TestVerticalQuotas(PrototypeTestBase):
    def runTest(self):
        pkt_send = (
            Ether()/
            IP(dst="10.0.0.2")/
            UDP(sport=9877, dport=9876)/
            ActiveState(fid=1)/
            ActiveProgram(opcode=self.OPCODES['MAR_LOAD'], arg=4096)/
            ActiveProgram(opcode=self.OPCODES['MBR_LOAD'], arg=17)/
            ActiveProgram(opcode=self.OPCODES['MEM_WRITE'])/
            ActiveProgram(opcode=self.OPCODES['ENABLE_EXEC'])/
            ActiveProgram(opcode=self.OPCODES['RETURN'])/
            ActiveProgram()/
            ActiveProgram(opcode=self.OPCODES['EOF'])
        )
        pkt_exp = copy.deepcopy(pkt_send)
        sync = active_generated_register_flags_t(read_hw_sync=1)
        send_packet(self, 0, pkt_send)
        verify_packet_prefix(self, pkt_exp, 4, 14)
        data = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, 1, sync)
        self.assertEquals(data[0], 16)"""
