import json
import atexit
import threading
import ctypes
import math
import random
import cmd
import sys
from Queue import Queue
from time import time
from time import sleep
from multiprocessing import Process
from signal import signal, SIGINT, SIGKILL

MBR_MIN         = 0
MBR_MAX         = 65535
ENABLED         = 0
DISABLED_SOFT   = 1
DISABLED_HARD   = 2

class Controller(threading.Thread):
    def __init__(self, listen = True):
        threading.Thread.__init__(self)
        self.digest = None
        self.CIR_KBPS = 1
        self.CBS_KBITS = 5
        self.PIR_CBPS = 5
        self.PBS_KBITS = 5
        self.hdl = []
        self.freqThres = {
            1   : 10
        }
        if listen:
            #p4_pd.meter_params_register()
            p4_pd.alloc_params_register()
            print "Registered listener"
        self.MEMSIZE = 65536
        self.execHandles = {}
        self.memHandles = {}
        self.vertalloc = {}
        self.lastAllocationId = {}
        self.weights = {
            1   : 1,
            2   : 1,
            3   : 1,
            4   : 1,
            5   : 1,
            6   : 1,
            7   : 1,
            8   : 1
        }
        self.OPCODES = json.loads(open('../../config/opcodes.json').read(), encoding='utf-8')
        self.OPS_MEMACCESS = [
            "MEM_READ",
            "MEM_WRITE",
            "COUNTER_RMW",
            "CMEM_WRITE",
            "CMEM_READ",
            "MEM_RST"
        ]
        self.ACTIONS = {
            'MEM_READ'          : 0,
            'MEM_WRITE'         : 1,
            'COUNTER_RMW'       : 2,
            'MEM_RST'           : 3,
            'CMEM_WRITE'        : 1,
            'CMEM_READ'         : 0
        }
        self.executeMatchSpecs = [
            p4_pd.execute_1_match_spec_t,
            p4_pd.execute_2_match_spec_t,
            p4_pd.execute_3_match_spec_t,
            p4_pd.execute_4_match_spec_t,
            p4_pd.execute_5_match_spec_t,
            p4_pd.execute_6_match_spec_t,
            p4_pd.execute_7_match_spec_t,
            p4_pd.execute_8_match_spec_t,
            p4_pd.execute_9_match_spec_t,
            p4_pd.execute_10_match_spec_t,
            p4_pd.execute_11_match_spec_t
        ]
        self.executeTableCmds = [
            [
                p4_pd.execute_1_table_add_with_memory_1_read,
                p4_pd.execute_1_table_add_with_memory_1_write,
                p4_pd.execute_1_table_add_with_counter_1_rmw,
                p4_pd.execute_1_table_add_with_memory_1_reset
            ],
            [
                p4_pd.execute_2_table_add_with_memory_2_read,
                p4_pd.execute_2_table_add_with_memory_2_write,
                p4_pd.execute_2_table_add_with_counter_2_rmw,
                p4_pd.execute_2_table_add_with_memory_2_reset
            ],
            [
                p4_pd.execute_3_table_add_with_memory_3_read,
                p4_pd.execute_3_table_add_with_memory_3_write,
                p4_pd.execute_3_table_add_with_counter_3_rmw,
                p4_pd.execute_3_table_add_with_memory_3_reset
            ],
            [
                p4_pd.execute_4_table_add_with_memory_4_read,
                p4_pd.execute_4_table_add_with_memory_4_write,
                p4_pd.execute_4_table_add_with_counter_4_rmw,
                p4_pd.execute_4_table_add_with_memory_4_reset
            ],
            [
                p4_pd.execute_5_table_add_with_memory_5_read,
                p4_pd.execute_5_table_add_with_memory_5_write,
                p4_pd.execute_5_table_add_with_counter_5_rmw,
                p4_pd.execute_5_table_add_with_memory_5_reset
            ],
            [
                p4_pd.execute_6_table_add_with_memory_6_read,
                p4_pd.execute_6_table_add_with_memory_6_write,
                p4_pd.execute_6_table_add_with_counter_6_rmw,
                p4_pd.execute_6_table_add_with_memory_6_reset
            ],
            [
                p4_pd.execute_7_table_add_with_memory_7_read,
                p4_pd.execute_7_table_add_with_memory_7_write,
                p4_pd.execute_7_table_add_with_counter_7_rmw,
                p4_pd.execute_7_table_add_with_memory_7_reset
            ],
            [
                p4_pd.execute_8_table_add_with_memory_8_read,
                p4_pd.execute_8_table_add_with_memory_8_write,
                p4_pd.execute_8_table_add_with_counter_8_rmw,
                p4_pd.execute_8_table_add_with_memory_8_reset
            ],
            [
                p4_pd.execute_9_table_add_with_memory_9_read,
                p4_pd.execute_9_table_add_with_memory_9_write,
                p4_pd.execute_9_table_add_with_counter_9_rmw,
                p4_pd.execute_9_table_add_with_memory_9_reset
            ],
            [
                p4_pd.execute_10_table_add_with_memory_10_read,
                p4_pd.execute_10_table_add_with_memory_10_write,
                p4_pd.execute_10_table_add_with_counter_10_rmw,
                p4_pd.execute_10_table_add_with_memory_10_reset
            ],
            [
                p4_pd.execute_11_table_add_with_memory_11_read,
                p4_pd.execute_11_table_add_with_memory_11_write,
                p4_pd.execute_11_table_add_with_counter_11_rmw,
                p4_pd.execute_11_table_add_with_memory_11_reset
            ]
        ]
        self.cmdExecuteTable = '''p4_pd.execute_%d_table_add_with_%s(
            p4_pd.execute_%d_match_spec_t(
                ap_%d__opcode=%d, 
                meta_disabled_start=%d, 
                meta_disabled_end=%d, 
                meta_mbr_start=%s,
                meta_mbr_end=%s, 
                meta_quota_start_start=%d, 
                meta_quota_start_end=%d, 
                meta_quota_end_start=%d, 
                meta_quota_end_end=%d, 
                meta_complete=0,
                meta_mar_start=%s,
                meta_mar_end=%s,
                as_fid=%d
            ), 
            1
        )'''
        self.initExecuteTables()
        random.seed(time())
 
    def initExecuteTables(self):
        for fid in range(1, 9):
            self.execHandles[fid] = []
            hdl = p4_pd.execute_3_table_add_with_memfault(
                p4_pd.execute_3_match_spec_t(
                    ap_2__opcode=4, 
                    meta_disabled_start=0, 
                    meta_disabled_end=0, 
                    meta_mbr_start=0,
                    meta_mbr_end=hex_to_i16(0xFFFF), 
                    meta_quota_start_start=1, 
                    meta_quota_start_end=11, 
                    meta_quota_end_start=1, 
                    meta_quota_end_end=11, 
                    meta_complete=0,
                    meta_mar_start=hex_to_i16(0),
                    meta_mar_end=hex_to_i16(0xFFFF),
                    as_fid=fid
                ),
                1
            )
            self.execHandles[fid].append(hdl)
        conn_mgr.complete_operations()

    def getNotification(self):
        #self.digest = p4_pd.meter_params_get_digest()
        self.digest = p4_pd.alloc_params_get_digest()
        if self.digest.msg != []:
            msgPtr = self.digest.msg_ptr
            self.digest.msg_ptr = 0
            #p4_pd.meter_params_digest_notify_ack(msgPtr)
            p4_pd.alloc_params_digest_notify_ack(msgPtr)
        return self.digest.msg

    def handleHotItems(self, fid, freq, key):
        print "received digest for fid %d with key %d and freq %d" % (fid, key, freq)
        p4_pd.register_write_frequency(key, 0)
        p4_pd.register_write_bloom(key, 0)

    def modifyExecuteTableHack(self):
        print "deleting existing entries"
        for fid in self.execHandles:
            if fid in self.vertalloc:
                for hdl in self.execHandles[fid]:
                    p4_pd.execute_3_table_delete(hdl)
                self.execHandles[fid] = []
        print "adding update entries"
        for fid in self.vertalloc:
            self.execHandles[fid] = []
            memStart = self.vertalloc[fid][0]
            memEnd = self.vertalloc[fid][1]
            hdl = p4_pd.execute_3_table_add_with_memory_3_read(
                p4_pd.execute_3_match_spec_t(
                    ap_2__opcode=4, 
                    meta_disabled_start=0, 
                    meta_disabled_end=0, 
                    meta_mbr_start=0,
                    meta_mbr_end=hex_to_i16(0xFFFF), 
                    meta_quota_start_start=1, 
                    meta_quota_start_end=11, 
                    meta_quota_end_start=1, 
                    meta_quota_end_end=11, 
                    meta_complete=0,
                    meta_mar_start=hex_to_i16(memStart),
                    meta_mar_end=hex_to_i16(memEnd),
                    as_fid=fid
                ),
                1
            )
            self.execHandles[fid].append(hdl)
            if memStart > 0:
                hdl = p4_pd.execute_3_table_add_with_memfault(
                    p4_pd.execute_3_match_spec_t(
                        ap_2__opcode=4, 
                        meta_disabled_start=0, 
                        meta_disabled_end=0, 
                        meta_mbr_start=0,
                        meta_mbr_end=hex_to_i16(0xFFFF), 
                        meta_quota_start_start=1, 
                        meta_quota_start_end=11, 
                        meta_quota_end_start=1, 
                        meta_quota_end_end=11, 
                        meta_complete=0,
                        meta_mar_start=hex_to_i16(0),
                        meta_mar_end=hex_to_i16(memStart - 1),
                        as_fid=fid
                    ),
                    1
                )
                self.execHandles[fid].append(hdl)
            if memEnd < 65535:
                hdl = p4_pd.execute_3_table_add_with_memfault(
                    p4_pd.execute_3_match_spec_t(
                        ap_2__opcode=4, 
                        meta_disabled_start=0, 
                        meta_disabled_end=0, 
                        meta_mbr_start=0,
                        meta_mbr_end=hex_to_i16(0xFFFF), 
                        meta_quota_start_start=1, 
                        meta_quota_start_end=11, 
                        meta_quota_end_start=1, 
                        meta_quota_end_end=11, 
                        meta_complete=0,
                        meta_mar_start=hex_to_i16(memEnd +1),
                        meta_mar_end=hex_to_i16(0xFFFF),
                        as_fid=fid
                    ),
                    1
                )
                self.execHandles[fid].append(hdl)
        print "added memory op entries for FID %d" % fid

    def modifyExecuteTable(self, fid, stageId, action, opcode, isDisabled, mbrStart, mbrEnd):
        if fid in self.execHandles and len(self.execHandles[fid]) > 0:
            print "deleting existing entries"
            for hdl in self.execHandles[fid]:
                p4_pd.execute_3_table_delete(hdl)
            self.execHandles[fid].clear()
        else:
            self.execHandles[fid] = []
        if isDisabled == ENABLED:
            disabledStart = 0
            disabledEnd = 0
        elif isDisabled == DISABLED_SOFT:
            disabledStart = 1
            disabledEnd = 1
        else:
            disabledStart = 2
            disabledEnd = 127       
        memStart = self.vertalloc[fid][0]
        memEnd = self.vertalloc[fid][1]
        """if memStart > 0:
            exec(self.cmdExecuteTable % (
                    stageId, 'memfault', stageId, 
                    stageId - 1, opcode, 
                    disabledStart, disabledEnd, 
                    mbrStart, mbrEnd, 
                    1, 11, 1, 11,
                    'hex_to_i16(0x0)', ('hex_to_i16(0x%x)' % (memStart - 1)),
                    fid
                )
            )
            self.execHandles[fid].append(hdl)
        if memEnd < 65535:
            exec(self.cmdExecuteTable % (
                    stageId, 'memfault', stageId, 
                    stageId - 1, opcode, 
                    disabledStart, disabledEnd, 
                    mbrStart, mbrEnd, 
                    1, 11, 1, 11,
                    ('hex_to_i16(0x%x)' % (memEnd + 1)), 'hex_to_i16(0xFFFF)',
                    fid
                )
            )
            self.execHandles[fid].append(hdl)"""
        hdl = self.executeTableCmds[stageId - 1][self.ACTIONS[action]](
            self.executeMatchSpecs[stageId - 1](
                opcode, 
                disabledStart, 
                disabledEnd, 
                hex_to_i16(mbrStart),
                hex_to_i16(mbrEnd), 
                1, 
                11, 
                1, 
                11, 
                hex_to_i16(memStart),
                hex_to_i16(memEnd),
                fid
            ),
            1
        )
        self.execHandles[fid].append(hdl)
        """cmd = self.cmdExecuteTable % (
            stageId, action, stageId, 
            stageId - 1, opcode, 
            disabledStart, disabledEnd, 
            mbrStart, mbrEnd, 
            1, 11, 1, 11,
            ('hex_to_i16(0x%x)' % memStart), ('hex_to_i16(0x%x)' % memEnd),
            fid
        )
        exec(cmd)"""
        print "added memory op entries for FID %d" % fid

    def modifyMemallocTable(self):
        for fid in self.memHandles:
            if fid in self.vertalloc:
                p4_pd.getalloc_table_delete(self.memHandles[fid])
        for fid in self.vertalloc:
            self.lastAllocationId[fid] = random.randint(0, 65535)
            self.memHandles[fid] = p4_pd.getalloc_table_add_with_return_allocation(
                p4_pd.getalloc_match_spec_t(
                    as_fid=fid,
                    as_flag_reqalloc=1
                ),
                p4_pd.return_allocation_action_spec_t(
                    hex_to_i16(self.lastAllocationId[fid]),
                    hex_to_i16(self.vertalloc[fid][0]),
                    hex_to_i16(self.vertalloc[fid][1])
                )
            )

    def vertAllocate(self, fid):
        self.vertalloc[fid] = None
        print "[MEMORY ALLOCATION SNAPSHOT]"
        wtSum = 0
        for fid in self.vertalloc:
            wtSum = wtSum + self.weights[fid]
        offset = 0
        for f in self.vertalloc:
            blockSize = math.floor(self.weights[f] * self.MEMSIZE / wtSum)
            self.vertalloc[f] = (offset, offset + blockSize - 1)
            offset = offset + blockSize
            print "FID %d [%d, %d]" % (f, self.vertalloc[f][0], self.vertalloc[f][1])
        print ""

    def handleMemoryRequest(self, fid):
        if fid in self.vertalloc:
            print "FID %d already present" % fid
            return
        self.vertAllocate(fid)
        try:
            self.modifyExecuteTableHack()
            """for stageId in range(1, 12):
                self.modifyExecuteTable(fid, stageId, 'MEM_READ', self.OPCODES['MEM_READ'], ENABLED, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('memory_%d_read' % stageId), self.OPCODES['CMEM_READ'], ENABLED, 0, 0)
                self.modifyExecuteTable(fid, stageId, 'skip', self.OPCODES['CMEM_READ'], ENABLED, 1, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('memory_%d_write' % stageId), self.OPCODES['MEM_WRITE'], ENABLED, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('memory_%d_write' % stageId), self.OPCODES['CMEM_WRITE'], ENABLED, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, 'skip', self.OPCODES['CMEM_WRITE'], DISABLED_SOFT, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('counter_%d_rmw' % stageId), self.OPCODES['COUNTER_RMW'], ENABLED, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('attempt_rejoin_%d' % stageId), self.OPCODES['MEM_READ'], DISABLED_HARD, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('attempt_rejoin_%d' % stageId), self.OPCODES['MEM_WRITE'], DISABLED_HARD, MBR_MIN, MBR_MAX)
                self.modifyExecuteTable(fid, stageId, ('attempt_rejoin_%d' % stageId), self.OPCODES['COUNTER_RMW'], DISABLED_HARD, MBR_MIN, MBR_MAX)"""
        except Exception as ex:
            template = "An exception of type {0} occurred in memupdate. Arguments:\n{1!r}"
            message = template.format(type(ex).__name__, ex.args)
            print message
        try:
            self.modifyMemallocTable()
        except Exception as ex:
            template = "An exception of type {0} occurred with memalloc. Arguments:\n{1!r}"
            message = template.format(type(ex).__name__, ex.args)
            print message
        p4_pd.register_write_bloom_alloc(fid, 0)
        conn_mgr.complete_operations()
        print "allocated %d - %d to FID %d" % (self.vertalloc[fid][0], self.vertalloc[fid][1], fid)

    def reset(self):
        for fid in self.memHandles:
            p4_pd.getalloc_table_delete(self.memHandles[fid])
        for fid in self.execHandles:
            for hdl in self.execHandles[fid]:
                p4_pd.execute_3_table_delete(hdl)
        conn_mgr.complete_operations()
        self.execHandles = {}
        self.memHandles = {}
        self.vertalloc = {}
        self.initExecuteTables()
        print "Allocation reset complete"
        #self.getAllocationEntries()

    def getAllocationEntries(self):
        MAX_HANDLES = 1000
        OPCODE_MEMREAD = 4
        head = p4_pd.execute_3_get_first_entry_handle()
        hdls = p4_pd.execute_3_get_next_entry_handles(head, MAX_HANDLES)
        print "<MEMORY ALLOCATION>"
        print ""
        for hdl in hdls:
            if hdl <= 0:
                continue
            entry = p4_pd.execute_3_get_entry(hdl, 0)
            action = str(entry.action_desc.name)
            if entry.match_spec.ap_2__opcode == OPCODE_MEMREAD or action == 'memfault':
                print "FID %d : [ %d, %u ] -> %s" % (entry.match_spec.as_fid, entry.match_spec.meta_mbr_start, entry.match_spec.meta_mbr_end & 0xFFFF, action)
        print ""

    def run(self):
        while True:
            try:
                digests = self.getNotification()
                for m in digests:
                    print m
                    fid = int(m.as_fid)
                    self.handleMemoryRequest(fid)
                    print "reallocation complete"
            except Exception as ex:
                template = "An exception of type {0} occurred while polling. Arguments:\n{1!r}"
                message = template.format(type(ex).__name__, ex.args)
                print message
                self.unregisterMMU()
                return
            sleep(0.000001)

    def unregisterMMU(self):
        print "unregistering MMU"
        try:
            """p4_pd.meter_params_digest_notify_ack(self.digest.msg_ptr)
            p4_pd.meter_params_digest_deregister()"""
            p4_pd.alloc_params_digest_notify_ack(self.digest.msg_ptr)
            p4_pd.alloc_params_digest_deregister()
        except:
            pass

class ControllerPrompt(cmd.Cmd):
    intro = "ActiveP4 Controller. Type help or ? to list commands.\n"
    prompt = "(activep4-ctrl) "

    def __init__(self, controller):
        cmd.Cmd.__init__(self)
        self.controller = controller

    def do_reset(self, arg):
        'Reset the controller and flush all FIDs.'
        self.controller.reset()

    """def do_dumpalloc(self, arg):
        'Dumps allocation from table.'
        self.controller.getAllocationEntries()"""

    def close(self):
        exit()

ctrl = Controller()
atexit.register(ctrl.unregisterMMU)

ctrl.start()
ControllerPrompt(ctrl).cmdloop()

print "controller exited"