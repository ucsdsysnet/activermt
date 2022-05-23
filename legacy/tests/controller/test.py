import pdb
import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *

from active_generated.p4_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *

import json
from time import time
from time import sleep

class ActiveState(Packet):
    name = "ActiveState"
    fields_desc = [
        ByteField("binder", 1),
        ByteField("flag", 0),
        ByteField("demand", 1),
        ShortField("fid", 0),
        ShortField("acc", 0),
        ShortField("acc2", 0),
        ByteField("done", 0),
        ShortField("id", 0)
    ]

class ActiveProgram(Packet):
    name = "ActiveProgram"
    fields_desc = [
        ByteField("flags", 0),
        ByteField("opcode", 0),
        ShortField("arg", 0),
        ByteField("goto", 0),
        ByteField("binder", 2)
    ]

bind_layers(UDP, ActiveState, dport=9876)
bind_layers(ActiveState, ActiveProgram, binder=1)
bind_layers(ActiveProgram, ActiveProgram, binder=2)

class PrototypeTestBase(pd_base_tests.ThriftInterfaceDataPlane):
    
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["active_generated"])
        self.dpmap = {}
        self.OPCODES = json.loads(open('prototype/opcodes.json').read(), encoding='utf-8')
        self.timeInitiated = None
        self.MEMORY_SIZE = 8192
        self.NUM_PIPES = 4
        self.ENTRY_TIMEOUT = 1.0

    def read_maps(self):
        with open('/tmp/dp_mappings_identity.csv', 'r') as f:
            lines = f.read().strip().splitlines()
            for l in lines:
                row = l.split(",")
                self.dpmap[int(row[0])] = int(row[1])
            f.close()

    def setUp(self):
        pd_base_tests.ThriftInterfaceDataPlane.setUp(self)
        self.sess_hdl = self.conn_mgr.client_init()
        self.dev      = 0
        self.dev_tgt  = DevTarget_t(self.dev, hex_to_i16(0xFFFF))
        print "Connected to Device %d with Session %d" % (self.dev, self.sess_hdl)
        self.read_maps()
        self.timeInitiated = time()
        self.conn_mgr.complete_operations(self.sess_hdl)
    
    def tearDown(self):
        self.conn_mgr.complete_operations(self.sess_hdl)
        self.conn_mgr.client_cleanup(self.sess_hdl)
        print "Closed Session %d" % self.sess_hdl
        pd_base_tests.ThriftInterfaceDataPlane.tearDown(self) 

class TestControllerTiming(PrototypeTestBase):
    def runTest(self):
        timeAverage = []
        for repeat in range(0, 1000):
            then = time()
            sync = active_generated_register_flags_t(read_hw_sync=1)
            data = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, 255, sync)
            now = time()
            elapsed = now - then
            timeAverage.append(elapsed)
        timeAverage.sort()
        print "median elapsed (ms) =", timeAverage[500] * 1000
        print "mean elapsed (ms) =", sum(timeAverage)

class RunController(PrototypeTestBase):
    def runTest(self):
        entryAge = [ {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} ]
        for repeat in range(0, 5):
            then = time()
            sync = active_generated_register_flags_t(read_hw_sync=1)
            for index in range(0, self.MEMORY_SIZE):
                values = self.client.register_read_heap_1(self.sess_hdl, self.dev_tgt, index, sync)
                for pipe in range(0, self.NUM_PIPES):
                    objKey = values[pipe].f1
                    if objKey != 0:
                        if index in entryAge[0]:
                            entryAge[0][index].end = time()
                        else:
                            entryAge[0][index].start = time()
                        elapsed = entryAge[0][index].end - entryAge[0][index].start
                        if elapsed >= self.ENTRY_TIMEOUT:
                            values[pipe].f1 = 0
                            values[pipe].f0 = 0
                            self.client.register_write_heap_1(self.sess_hdl, self.dev_tgt, index, values)
            now = time()
            elapsed = now - then
            print "elapsed =", elapsed