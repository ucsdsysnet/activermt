import os

from scapy.all import *
from headers import *
from ap4common import *

from ptf.testutils import *
from bfruntime_client_base_tests import BfRuntimeTest
import bfrt_grpc.bfruntime_pb2 as bfruntime_pb2
import bfrt_grpc.client as gc

class ActiveRMTTest(BfRuntimeTest):
    
    def setUp(self):
        self.client_id = 0
        self.p4_name   = test_param_get('active', '')
        self.dev       = 0
        self.dev_tgt   = gc.Target(self.dev, pipe_id=0xFFFF)

        BfRuntimeTest.setUp(self, self.client_id, self.p4_name)

        self.bfrt_info = self.interface.bfrt_info_get()

        self.arch   = test_param_get('arch')
        self.target = test_param_get('target')

        BASE_DIR = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', '..'))
        IP_CONFIG = 'model'

        self.ip_route = {}
        ipconfig_path = os.path.join(BASE_DIR, 'config', 'ip_routing_{}.csv'.format(IP_CONFIG))
        assert(os.path.exists(ipconfig_path))

        with open(ipconfig_path) as f:
            for line in f.read().splitlines():
                entry = line.split(',')
                ip_addr = entry[0]
                port = int(entry[1])
                self.ip_route[ip_addr] = port
            f.close()

        self.used_tables = []

        self.ipv4_host = self.bfrt_info.table_get('Ingress.ipv4_host')
        self.used_tables.append(self.ipv4_host)

        self.clearTables(self.used_tables)
        self.installForwardingEntries()

    def tearDown(self):
        self.clearTables(self.used_tables)
        BfRuntimeTest.tearDown(self)

    def clearTables(self, tables):
        try:
            for t in tables:
                t.entry_del(self.dev_tgt, [])
                try:
                    t.default_entry_reset(self.dev_tgt)
                except:
                    pass
        except Exception as e:
            print('Error clearing {}'.format(e))

    def installForwardingEntries(self):
        self.ipv4_host.info.key_field_annotation_add("hdr.ipv4.dst_addr", "ipv4")
        self.ipv4_host.info.data_field_annotation_add("mac", "Ingress.send", "mac")
        mac_id = 0
        for ip_addr in list(self.ip_route.keys()):
            port = self.ip_route[ip_addr]
            mac_id = mac_id + 1
            ipv4_dst = test_param_get("ipv4_dst", ip_addr)
            eth_dst  = test_param_get("eth_dst", "00:00:00:00:00:{:02x}".format(mac_id))
            self.ipv4_host.entry_add(
                self.dev_tgt, 
                [self.ipv4_host.make_key([gc.KeyTuple('hdr.ipv4.dst_addr', ipv4_dst)])], 
                [self.ipv4_host.make_data([gc.DataTuple('port', port), gc.DataTuple('mac', eth_dst)], "Ingress.send")]
            )

    def installNOPRuntime(self):
        OPCODE_EOF = 0
        OPCODE_NOP = 1
        OPCODE_RETURN = 2
        ops = [(OPCODE_EOF, 'mark_termination'), (OPCODE_NOP, 'skip'), (OPCODE_RETURN, 'complete')]
        num_stages_gress = 10
        for i in range(num_stages_gress):
            instr_tbl_ig = self.bfrt_info.table_get("Ingress.instruction_{}".format(i))
            self.used_tables.append(instr_tbl_ig)
            for op in ops:
                action_id = "Ingress.{}".format(op[1])
                instr_tbl_ig.entry_add(
                    self.dev_tgt,
                    [instr_tbl_ig.make_key([
                        gc.KeyTuple('hdr.meta.fid', low=0, high=255),
                        gc.KeyTuple('hdr.instr${}.opcode'.format(i), op[0]),
                        gc.KeyTuple('hdr.meta.complete', 0),
                        gc.KeyTuple('hdr.meta.disabled', 0),
                        gc.KeyTuple('hdr.meta.mbr', 0, prefix_len=0),
                        gc.KeyTuple('hdr.meta.mar[19:0]', low=0, high=0xFFFFF)
                    ])],
                    [instr_tbl_ig.make_data([], action_id)]
                )
            instr_tbl_eg = self.bfrt_info.table_get("Egress.instruction_{}".format(i))
            self.used_tables.append(instr_tbl_eg)
            for op in ops:
                action_id = "Egress.{}".format(op[1])
                instr_tbl_eg.entry_add(
                    self.dev_tgt,
                    [instr_tbl_eg.make_key([
                        gc.KeyTuple('hdr.meta.fid', low=0, high=255),
                        gc.KeyTuple('hdr.instr${}.opcode'.format(i), op[0]),
                        gc.KeyTuple('hdr.meta.complete', 0),
                        gc.KeyTuple('hdr.meta.disabled', 0),
                        gc.KeyTuple('hdr.meta.mbr', 0, prefix_len=0),
                        gc.KeyTuple('hdr.meta.mar[19:0]', low=0, high=0xFFFFF)
                    ])],
                    [instr_tbl_eg.make_data([], action_id)]
                )

    def getIP(self, idx):
        ip_addr = list(self.ip_route.keys())[idx]
        port = self.ip_route[ip_addr]
        return ip_addr, port

    def constructActivePacket(self, fid, program, argvals=[], src="10.0.0.1", dst="10.0.0.2"):
        eth_src = "00:00:00:00:00:{:02x}".format(self.ip_route[src] + 1) if src in self.ip_route else "00:00:00:00:00:01"
        eth_dst = "00:00:00:00:00:{:02x}".format(self.ip_route[dst] + 1) if dst in self.ip_route else "00:00:00:00:00:02"
        flags = 0x8000
        pkt = (
            Ether(type=0x83b2, src=eth_src, dst=eth_dst)/
            ActiveInitialHeader(fid=fid, flags=flags)
        )
        kwargs = {
            'data_0'    : 0,
            'data_1'    : 0,
            'data_2'    : 0,
            'data_3'    : 0
        }
        for didx in range(0, len(argvals)):
            kwargs['data_%d' % didx] = argvals[didx]
        pkt = pkt / ActiveArguments(**kwargs)
        last_opcode = 0
        for i in range(0, len(program)):
            last_opcode = program[i].opcode
            pkt = pkt / ActiveInstructionHeader(opcode=program[i].opcode, goto=program[i].goto)
        if last_opcode != 0:
            pkt = pkt / ActiveInstructionHeader(opcode=0)
        pkt = pkt / IP(src=src, dst=dst, proto=0x06)
        pkt = pkt / TCP()
        return pkt