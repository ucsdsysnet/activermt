import os
import math
import sys
import time
import json
import inspect
import threading
import queue
import logging
import random

SDE_PATH = os.environ['SDE']

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)

config = None
if os.path.exists(os.path.join(SDE_PATH, 'controller.json')):
    with open(os.path.join(SDE_PATH, 'controller.json')) as f:
        config = json.loads(f.read())
        f.close()

basePath = os.getcwd()
refPath = basePath

if config is not None:
    basePath = config['BASE_PATH']
    refPath = config['REF_PATH']

print("Using base path:", basePath)
print("Using ref path:", refPath)
print("Using python version", VERSION)

sys.path.insert(0, os.path.join(basePath, 'malloc'))
sys.path.insert(0, os.path.join(SDE_PATH, 'install/lib/python%s/site-packages' % VERSION))
sys.path.insert(0, '/usr/local/lib/python%s/dist-packages' % VERSION)

import allocator as ap4alloc
import numpy as np

from netaddr import IPAddress

class ActiveP4Controller:

    global os
    global np
    global bfrt
    global math
    global time
    global inspect
    global threading
    global queue
    global logging
    global random
    global IPAddress
    global ap4alloc

    REG_MAX = 0xFFFFF
    DEBUG = True

    def __init__(self, allocator=None, custom=None, basePath=""):
        if allocator is None:
            self.allocator = ap4alloc.Allocator(debug=self.DEBUG)
        else:
            self.allocator = allocator
        self.p4 = bfrt.active.pipe
        self.erase = True
        self.watchdog = True
        self.block_size = 8192
        self.num_stages_ingress = 10
        self.num_stages_egress = 10
        self.max_constraints = 8
        self.num_stages_total = self.num_stages_ingress + self.num_stages_egress
        self.max_stage_sharing = 8
        self.max_iter = 100
        self.recirculation_enabled = True
        self.base_path = basePath
        logging.basicConfig(filename=os.path.join(self.base_path, 'logs/controller/controller.log'), format='%(asctime)s - %(message)s', level=logging.INFO)
        self.customInstructionSet = custom
        self.opcode_action = {}
        self.opcodes_memaccess = []
        with open('%s/config/opcode_action_mapping.csv' % self.base_path) as f:
            mapping = f.read().strip().splitlines()
            for opcode in range(0, len(mapping)):
                m = mapping[opcode].split(',')
                pnemonic = m[0]
                action = m[1]
                conditional = ((m[2] == '1') if len(m) == 3 else None)
                meminstr = pnemonic.startswith('MEM')
                if self.customInstructionSet is not None and opcode not in self.customInstructionSet:
                    continue
                self.opcode_action[pnemonic] = {
                    'opcode'    : opcode,
                    'action'    : action,
                    'condition' : conditional,
                    'memory'    : meminstr,
                    'args'      : None
                }
                if meminstr:
                    self.opcodes_memaccess.append(opcode)
            f.close()
        if self.customInstructionSet is not None:
            print("Using restricted instruction set.")
            print(self.opcode_action)
        self.sid_to_port_mapping = {}
        self.dst_port_mapping = {}
        self.ports = []
        # modified at runtime.
        self.allocVersion = {}
        self.queue = []
        self.allocationRequests = queue.Queue()
        self.active = []
        self.coredumps = {}
        self.coredumpQueue = set()
        self.remoteDrainQueue = {}
        self.remoteDrainInit = set()
        self.remoteDrainInitiator = None
        self.mutex = threading.Lock()
        self.monitorThread = None

    def save(self):
        """ctrlstate = {
            'active'    : self.active,
            'coredump'  : self.coredumps,
            'memsyncq'  : self.coredumpQueue
        }
        data = json.dumps(ctrlstate, indent=4)
        with open(os.path.join(self.base_path, 'bfrt', 'ctrl', 'snapshot.json'), 'w') as f:
            f.write(data)
            f.close()
        self.allocator.save()"""
        pass

    # Taken from ICA examples
    def clear_all(self, verbose=DEBUG, batching=True):
        for table_types in (['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR'],
                            ['SELECTOR'],
                            ['ACTION_PROFILE']):
            for table in self.p4.info(return_info=True, print_info=False):
                if table['type'] in table_types:
                    if verbose:
                        print("Clearing table {:<40} ... ".
                            format(table['full_name']), end='', flush=True)
                    table['node'].clear(batch=batching)
                    if verbose:
                        print('Done')

    def installForwardingTableEntries(self, config='ptf'):
        vport_dst_mapping = {}
        port_to_mac = {}
        with open(os.path.join(self.base_path, 'config', 'ip_routing_%s.csv' % config)) as f:
            entries = f.read().splitlines()
            for row in entries:
                record = row.split(",")
                ip_addr = record[0]
                dport = int(record[1])
                vport = record[2]
                self.dst_port_mapping[ip_addr] = dport
                if dport not in self.ports:
                    self.ports.append(dport)
                if vport != '':
                    vport_dst_mapping[int(vport)] = ip_addr
            f.close()
        with open(os.path.join(self.base_path, 'config', 'arp_table_%s.csv' % config)) as f:
            entries = f.read().strip().splitlines()
            for row in entries:
                record = row.split(",")
                ip_addr = record[0]
                mac_addr = record[1]
                dport = int(record[2])
                port_to_mac[dport] = mac_addr
            f.close()
        ipv4_host = self.p4.Ingress.ipv4_host
        #vroute = self.p4.Ingress.vroute
        for host in self.dst_port_mapping:
            ipv4_host.add_with_send(dst_addr=IPAddress(host), port=self.dst_port_mapping[host], mac=port_to_mac[self.dst_port_mapping[host]])
        """for vport in vport_dst_mapping:
            vroute.add_with_send(port_change=1, vport=vport, port=dst_port_mapping[vport_dst_mapping[vport]], mac=port_to_mac[dst_port_mapping[vport_dst_mapping[vport]]])"""
        bfrt.complete_operations()
        #ipv4_host.dump(table=True)
        #info = ipv4_host.info(return_info=True, print_info=False)

    def fetchMemoryAccessEntries(self, stageId, gress):
        instr_table = getattr(gress, 'instruction_%d' % stageId)
        entries = instr_table.dump(return_ents=True)
        memaccessEntries = {}
        if entries is not None:
            for entry in entries:
                fid = entry.key.get(b'hdr.meta.fid')[0]
                opcode = entry.key.get(b'hdr.instr$%d.opcode' % stageId)
                if opcode in self.opcodes_memaccess:
                    if fid not in memaccessEntries:
                        memaccessEntries[fid] = []
                    memaccessEntries[fid].append(entry)
        return memaccessEntries

    def fetchAllocationTableEntries(self, stageId):
        alloc_table = getattr(self.p4.Ingress, 'allocation_%d' % stageId)
        entries = alloc_table.dump(return_ents=True)
        allocationEntries = {}
        if entries is not None:
            for entry in entries:
                fid = entry.key.get(b'hdr.ih.fid')
                if fid not in allocationEntries:
                    allocationEntries[fid] = []
                allocationEntries[fid].append(entry)
        return allocationEntries

    def removeInstructionEntries(self, entries):
        for entry in entries:
            entry.remove()
        bfrt.complete_operations()

    def installInstructionTableEntry(self, fid, act, gress, stageId, memStart=0, memEnd=REG_MAX):
        instr_table = getattr(gress, 'instruction_%d' % stageId)
        add_method = getattr(instr_table, 'add_with_%s' % act['action'].replace('#', str(stageId)))
        add_method_skip = getattr(instr_table, 'add_with_skip')
        add_method_rejoin = getattr(instr_table, 'add_with_attempt_rejoin_s%s' % str(stageId))
        fid_start = fid if act['memory'] else 0
        fid_end = fid if act['memory'] else 0xFF
        if act['condition'] is not None:
            if act['condition']:
                add_method_skip(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=0, disabled=0, mbr=0, mbr_p_length=32, mar_19_0__start=memStart, mar_19_0__end=self.REG_MAX)
                add_method(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=0, disabled=0, mbr=0, mbr_p_length=0, mar_19_0__start=memStart, mar_19_0__end=memEnd)
            else:
                add_method(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=0, disabled=0, mbr=0, mbr_p_length=32, mar_19_0__start=memStart, mar_19_0__end=memEnd)
                add_method_skip(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=0, disabled=0, mbr=0, mbr_p_length=0, mar_19_0__start=memStart, mar_19_0__end=self.REG_MAX)
        else:
            if act['opcode'] == 0:
                add_method(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=1, disabled=0, mbr=0, mbr_p_length=0, mar_19_0__start=memStart, mar_19_0__end=memEnd)
            add_method(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=0, disabled=0, mbr=0, mbr_p_length=0, mar_19_0__start=memStart, mar_19_0__end=memEnd)
        add_method_rejoin(fid_start=fid_start, fid_end=fid_end, opcode=act['opcode'], complete=0, disabled=1, mbr=0, mbr_p_length=0, mar_19_0__start=memStart, mar_19_0__end=self.REG_MAX)
        #instr_table.dump(table=True)

    def installInstructionTableEntriesGress(self, gress, num_stages, offset=0):
        for i in range(offset, num_stages + offset):
            numEntries = 0
            for a in self.opcode_action:
                act = self.opcode_action[a]
                if act['action'] == 'NULL' or act['memory']: 
                    continue
                self.installInstructionTableEntry(0, act, gress, i)
                numEntries = numEntries + 1
            #print(gress, "%d entries installed on stage %d" % (numEntries, i))
        bfrt.complete_operations()

    def installInstructionTableEntries(self):
        self.installInstructionTableEntriesGress(self.p4.Ingress, self.num_stages_ingress)
        self.installInstructionTableEntriesGress(self.p4.Egress, self.num_stages_egress)

    def addQuotas(self, fid, recirculate=False):
        #rand_thresh = math.floor(recirc_pct * 0xFFFF)
        if(recirculate):
            self.p4.Ingress.quota_recirc.add_with_enable_recirculation(fid=fid)

    def createSidToPortMapping(self):
        self.sid_to_port_mapping = {}
        sid = 0
        for port in self.ports:
            sid = sid + 1
            self.sid_to_port_mapping[sid] = port
        print(self.sid_to_port_mapping)
    
    def setMirrorSessions(self):
        if not self.recirculation_enabled:
            return
        mirrorInfo = bfrt.mirror.info(return_info=True)[0]
        if mirrorInfo['type'] == 'MIRROR_CFG' and mirrorInfo['usage'] > 0:
            return
        for sid in self.sid_to_port_mapping:
            bfrt.mirror.cfg.add_with_normal(sid=sid, direction='EGRESS', session_enable=True, ucast_egress_port=self.sid_to_port_mapping[sid], ucast_egress_port_valid=1, max_pkt_len=16384)
            self.p4.Egress.mirror_cfg.add_with_set_mirror(egress_port=self.sid_to_port_mapping[sid], sessid=sid)
            self.p4.Egress.mirror_ack.add_with_ack(remap=1, ingress_port=self.sid_to_port_mapping[sid], sessid=sid)
        #bfrt.mirror.dump()

    def getTrafficCounters(self, fids):
        traffic_overall = self.p4.Ingress.overall_stats.get(0)
        traffic_by_fid = {}
        for fid in fids:
            traffic_ig = self.p4.Ingress.activep4_stats.get(fid)
            traffic_eg = self.p4.Egress.activep4_stats.get(fid)
            traffic_by_fid[fid] = {
                'ingress'   : traffic_ig,
                'egress'    : traffic_eg
            }
        return (traffic_overall, traffic_by_fid)

    def installControlEntries(self):
        self.p4.Ingress.routeback.add_with_route_malloc(flag_reqalloc=1)
        self.p4.Ingress.routeback.add_with_route_malloc(flag_reqalloc=2)

    def getMemoryDump(self, memId, memRange):
        gress = self.p4.Ingress if memId < self.num_stages_ingress else self.p4.Egress
        memIdGress = memId if memId < self.num_stages_ingress else memId - self.num_stages_ingress
        register = getattr(gress, 'heap_s%d' % memIdGress)
        print("Memory dump initiated ... ")
        data = []
        register.operation_register_sync()
        for regId in range(memRange[0], memRange[1] + 1):
            item = register.get(REGISTER_INDEX=regId, from_hw=False)
            regId = item.key[b'$REGISTER_INDEX']
            regVal = item.data[b'Ingress.heap_s%d.f1' % memIdGress]
            data.append((regId, regVal))
            if self.erase:
                register.add(REGISTER_INDEX=regId, f1=0)
        """register.operation_register_sync()
        regValues = register.dump(return_ents=True, from_hw=False)
        for item in regValues:
            regId = item.key[b'$REGISTER_INDEX']
            regVal = item.data[b'Ingress.heap_s%d.f1' % memIdGress]
            if regId >= memRange[0] and regId <= memRange[1]:
                data.append((regId, regVal))
        if self.erase:
            register.clear()
            for regId in range(memRange[0], memRange[1] + 1):
                register.add(REGISTER_INDEX=regId, f1=0)"""
        print("Memory dump complete.")
        data.sort(key=lambda x: x[0])
        return data    

    """def resetTrafficCounters(self):
        self.p4.Ingress.activep4_stats.clear()
        self.p4.Egress.activep4_stats.clear()
        self.p4.Ingress.overall_stats.clear()

    def installInBatches(self):
        bfrt.batch_begin()
        try:
            pass
        except BfRtTableError as e:
            if e.sts == 4:
                print("Duplicate entry")
        bfrt.batch_end()"""

    def coredump(self, remaps, fid, callback=None):
        # if fid in self.coredumpQueue:
        #    return
        for tid in remaps:
            if tid in self.coredumpQueue:
                return
        tStart = time.time()
        for tid in remaps:
            self.coredumpQueue.add(tid)
            self.coredumps[tid] = {}
            for remap in remaps[tid]:
                stageId = remap[0]
                allocation = remap[1]
                memRange = self.getMemoryRange(allocation)
                data = self.getMemoryDump(stageId, memRange)
                self.coredumps[tid][stageId] = data
            self.coredumpQueue.remove(tid)
            if tid in self.remoteDrainQueue:
                self.remoteDrainQueue.pop(tid)
            if tid in self.remoteDrainInit:
                self.p4.Ingress.remap_check.delete(fid=tid, flag_initiated=0)
                self.remoteDrainInit.remove(tid)
            bfrt.complete_operations()
        tElapsed = time.time() - tStart
        if self.DEBUG:
            print("Coredump (elapsed)", tElapsed)
        self.save()
        self.resumeAllocation(fid, remaps)

    def getMemoryRange(self, allocationBlocks):
        if len(allocationBlocks) == 0:
            return (0, 0)
        blockStart = allocationBlocks[0]
        blockEnd = allocationBlocks[-1]
        memStart = self.block_size * blockStart
        memEnd = self.block_size * (blockEnd + 1) - 1
        return (memStart, memEnd)

    def installMemoryAccessEntries(self, gress, stageIdGress, fid, allocationBlocks):
        (memStart, memEnd) = self.getMemoryRange(allocationBlocks)
        for pnemonic in self.opcode_action:
            act = self.opcode_action[pnemonic]
            if act['memory']:
                self.installInstructionTableEntry(fid, act, gress, stageIdGress, memStart=memStart, memEnd=memEnd)

    def resumeAllocation(self, fid, remaps):
        self.mutex.acquire()
        print("Resuming allocation for FID %d ... " % fid)
        print("Remaps ::", remaps)
        if self.remoteDrainInitiator is None:
            self.mutex.release()
            return
        self.allocator.applyQueuedAllocation()
        self.updateAllocation(fid, self.allocator.getAllocationBlocks(fid), remaps)
        self.addQuotas(fid, recirculate=True)
        if fid not in self.allocVersion:
            self.allocVersion[fid] = 0
        self.allocVersion[fid] += 1
        self.p4.Ingress.allocation.delete(fid=fid, flag_reqalloc=2)
        self.p4.Ingress.allocation.add_with_allocated(fid=fid, flag_reqalloc=2, allocation_id=self.allocVersion[fid])
        bfrt.complete_operations()
        self.active.append(fid)
        self.queue.remove(fid)
        self.remoteDrainInitiator = None
        self.save()
        self.mutex.release()

    def updateAllocation(self, fid, allocation, remaps):

        # build data structure for remapping.
        remappedStages = {}
        for tid in remaps:
            for remap in remaps[tid]:
                stageId = remap[0]
                if stageId not in remappedStages:
                    remappedStages[stageId] = []
                remappedStages[stageId].append((tid, remap[2], remap[1], remap[3]))

        # update memory access entries for remapped apps.
        for stageId in remappedStages:
            gress = self.p4.Ingress if stageId < self.num_stages_ingress else self.p4.Egress
            stageIdGress = stageId if stageId < self.num_stages_ingress else stageId - self.num_stages_ingress
            accessTEntries = self.fetchMemoryAccessEntries(stageIdGress, gress)
            for remap in remappedStages[stageId]:
                tid = remap[0]
                if tid in accessTEntries:
                    for entry in accessTEntries[tid]:
                        entry.remove()
                self.installMemoryAccessEntries(gress, stageIdGress, tid, remap[3])

        # build data structures for allocation tables and items to purge.
        allocRemapTable = {}
        staleAllocs = {}
        for stageId in remappedStages:
            stageIdGress = stageId if stageId < self.num_stages_ingress else stageId - self.num_stages_ingress
            if stageIdGress not in staleAllocs:
                staleAllocs[stageIdGress] = {}
            for remap in remappedStages[stageId]:
                tid = remap[0]
                if tid not in staleAllocs[stageIdGress]:
                    staleAllocs[stageIdGress][tid] = True
                tStageId = remap[1]
                tAllocation = remap[3]
                tstageIdGress = stageId if stageId < self.num_stages_ingress else stageId - self.num_stages_ingress
                if tid not in allocRemapTable:
                    allocRemapTable[tid] = {}
                if tstageIdGress not in allocRemapTable[tid]:
                    allocRemapTable[tid][tstageIdGress] = [[],[]]
                if tStageId < self.num_stages_ingress:
                    allocRemapTable[tid][tstageIdGress][0] = tAllocation
                else:
                    allocRemapTable[tid][tstageIdGress][1] = tAllocation

        # purge stale allocation table entries.
        for stageIdGress in staleAllocs:
            allocTable = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % stageIdGress)
            allocTableActionSpecDefault = getattr(allocTable, 'add_with_default_allocation_s%d' % stageIdGress)
            allocTEntries = self.fetchAllocationTableEntries(stageIdGress)
            for tid in staleAllocs[stageIdGress]:
                if tid in allocTEntries:
                    for entry in allocTEntries[tid]:
                        entry.remove()
                if stageIdGress not in allocRemapTable[tid]:
                    allocTableActionSpecDefault(fid=tid, flag_allocated=1)
        
        # install remapped allocation table entries.
        for tid in allocRemapTable:
            for stageId in allocRemapTable[tid]:
                (memStartIg, memEndIg) = self.getMemoryRange(allocRemapTable[tid][stageId][0])
                (memStartEg, memEndEg) = self.getMemoryRange(allocRemapTable[tid][stageId][1])
                allocTable = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % stageId)
                allocTableActionSpec = getattr(allocTable, 'add_with_get_allocation_s%d' % stageId)
                allocTableActionSpec(fid=tid, flag_allocated=1, offset_ig=memStartIg, size_ig=memEndIg, offset_eg=memStartEg, size_eg=memEndEg)
                
        # build data structure for allocation table entries.
        print("allocation ::", allocation)
        allocationTableGroups = np.zeros((4, self.num_stages_ingress))
        for stageId in allocation:
            gress = self.p4.Ingress if stageId < self.num_stages_ingress else self.p4.Egress
            stageIdGress = stageId if stageId < self.num_stages_ingress else stageId - self.num_stages_ingress
            self.installMemoryAccessEntries(gress, stageIdGress, fid, allocation[stageId])
            (memStart, memEnd) = self.getMemoryRange(allocation[stageId])
            if stageId < self.num_stages_ingress:
                allocationTableGroups[0, stageId] = memStart
                allocationTableGroups[1, stageId] = memEnd
            else:
                allocationTableGroups[2, stageIdGress] = memStart
                allocationTableGroups[3, stageIdGress] = memEnd

        # install allocation table entries.
        validity = np.sum(allocationTableGroups, axis=0)
        for i in range(0, self.num_stages_ingress):
            allocTable = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % i)
            allocTableActionSpec = getattr(allocTable, 'add_with_get_allocation_s%d' % i)
            allocTableActionSpecDefault = getattr(allocTable, 'add_with_default_allocation_s%d' % i)
            if validity[i] > 0:
                igOffset = allocationTableGroups[0, i]
                igSize = allocationTableGroups[1, i]
                egOffset = allocationTableGroups[2, i]
                egSize = allocationTableGroups[3, i]
                allocTableActionSpec(fid=fid, flag_allocated=1, offset_ig=igOffset, size_ig=igSize, offset_eg=egOffset, size_eg=egSize)
            else:
                allocTableActionSpecDefault(fid=fid, flag_allocated=1)

        bfrt.complete_operations()

        print("Allocation complete for FID", fid)

    """def allocatorRandomized(self, constr):

        numAccesses = len(constr)
        stageWiseAlloc = np.sum(self.allocation, axis=0)
        alloc = stageWiseAlloc > np.zeros(self.num_stages_total)

        constrLB = np.zeros(numAccesses)
        constrUB = np.zeros(numAccesses)
        constrMS = np.zeros(numAccesses)

        for i in range(0, numAccesses):
            constrLB[i] = constr[i][0]
            constrUB[i] = constr[i][1]
            constrMS[i] = constr[i][2]

        A = np.zeros((numAccesses, numAccesses))
        A[0, 0] = 1
        for i in range(1, numAccesses):
            A[i, i-1] = -1
            A[i, i] = 1
        
        numTrialsOuter = 0
        numTrialsInner = 0
        allocationValid = False
        for i in range(0, self.max_iter):
            isValid = False
            numTrialsOuter = numTrialsOuter + 1
            while not isValid:
                memIdx = np.random.randint(0, self.num_stages_total - 1, numAccesses)
                sep = np.transpose(np.matmul(A, np.transpose(memIdx)))
                isValid = np.all(memIdx >= constrLB) and np.all(memIdx <= constrUB) and np.all(sep >= constrMS)
                numTrialsInner = numTrialsInner + 1
            if not np.any(alloc[memIdx]):
                allocationValid = True
                break
        
        return (memIdx, allocationValid, numTrialsOuter, numTrialsInner)"""

    def deallocate(self, fid):

        print("Deallocating ", fid, " ... ")

        for stageId in range(0, self.num_stages_egress):
            entries = self.fetchMemoryAccessEntries(stageId, self.p4.Egress)
            if fid in entries:
                for entry in entries[fid]:
                    entry.remove()

        for stageId in range(0, self.num_stages_ingress):
            entries = self.fetchMemoryAccessEntries(stageId, self.p4.Ingress)
            if fid in entries:
                for entry in entries[fid]:
                    entry.remove()
            allocs = self.fetchAllocationTableEntries(stageId)
            if fid in allocs:
                for entry in allocs[fid]:
                    entry.remove()

        allocreqs = self.p4.Ingress.allocation.dump(return_ents=True)
        for entry in allocreqs:
            afid = entry.key.get(b'hdr.ih.fid')
            if afid == fid:
                entry.remove()

        self.p4.Ingress.quota_recirc.delete(fid=fid)

        bfrt.complete_operations()

        self.allocator.deallocate(fid)

        print("Deallocated ", fid)

    def allocate(self, fid, progLen, igLim, accessIdx, minDemand):

        if fid in self.queue or fid in self.active:
            return

        if igLim == 255:
            igLim = -1

        tsOverallStart = time.time()

        self.queue.append(fid)

        if self.DEBUG:
            print("Attempting allocation for FID", fid)

        self.p4.Ingress.allocation.add_with_pending(fid=fid, flag_reqalloc=2)
        bfrt.complete_operations()

        tsAllocationStart = time.time()

        accessIdx = np.array(accessIdx, dtype=np.uint32)
        minDemand = np.array(minDemand, dtype=np.uint32)

        if self.DEBUG:
            print("Program length", progLen, "IGLIM", igLim)
            print("Constraints:")
            print(accessIdx)
            print(minDemand)

        activeFunc = ap4alloc.ActiveFunction(fid, accessIdx, igLim, progLen, minDemand, enumerate=True)

        (memIdx, cost, utilization, allocTime, overallAlloc, allocationMap) = self.allocator.computeAllocation(activeFunc)
        if memIdx is not None and cost < self.allocator.WT_OVERFLOW:
            (changes, remaps) = self.allocator.enqueueAllocation(overallAlloc, allocationMap)
            
        tsAllocationStop = time.time()

        elapsedAllocation = tsAllocationStop - tsAllocationStart
        if self.DEBUG:
            print("Elapsed (allocation) time", elapsedAllocation)

        if cost > self.allocator.WT_OVERFLOW:
            self.p4.Ingress.allocation.delete(fid=fid, flag_reqalloc=2)
            bfrt.complete_operations()
            self.queue.remove(fid)
            if self.DEBUG:
                print("Allocation failed for FID", fid)
            return 

        self.remoteDrainInitiator = fid
        if not changes:
            if self.DEBUG:
                print("No changes detected. Applying allocation ... ")
            self.resumeAllocation(fid, remaps)
        else:
            if self.DEBUG:
                print("Initiating remote drain for FID", fid)
            th = threading.Thread(target=self.coredump, args=(remaps, fid, self.resumeAllocation,))
            th.start()
            for tid in remaps:
                print("Queueing FID %d for remapping ... " % tid)
                self.remoteDrainInit.add(tid)
                self.remoteDrainQueue[tid] = remaps
                self.p4.Ingress.remap_check.add_with_remapped(fid=tid, flag_initiated=0, allocation_id=self.allocVersion[tid])
                bfrt.complete_operations()

        tsOverallStop = time.time()

        elapsedOverall = tsOverallStop - tsOverallStart
        if self.DEBUG:
            print("Elapsed (overall) time", elapsedOverall)

    def resetAllocation(self):
        self.mutex.acquire()
        print("Initiating allocation reset ... ")
        completed = []
        for fid in self.active:
            self.deallocate(fid)
            completed.append(fid)
        for fid in completed:
            self.active.remove(fid)
        if self.DEBUG:
            print(self.allocator.allocationMatrix)
        self.mutex.release()

    def onMallocRequest(self, dev_id, pipe_id, directon, parser_id, session, msg):
        for digest in msg:
            fid = digest['fid']
            progLen = digest['proglen']
            igLim = digest['iglim']
            accessIdx = []
            minDemand = []
            if fid in self.active:
                continue
            if fid == 255:
                th = threading.Thread(target=self.resetAllocation)
                th.start()
                continue
            for i in range(0, self.max_constraints):
                memIdx = digest['mem_%d' % i]
                demand = digest['dem_%d' % i]
                if demand > 0:
                    accessIdx.append(memIdx)
                    minDemand.append(demand)
            self.allocationRequests.put({
                'fid'       : fid,
                'progLen'   : progLen,
                'igLim'     : igLim,
                'accessIdx' : accessIdx,
                'minDemand' : minDemand
            })
        return 0

    def onRemapAck(self, dev_id, pipe_id, directon, parser_id, session, msg):
        for digest in msg:
            fid = digest['fid']
            isRemap = (int(digest['flag_remapped']) == 1)
            isAck = (int(digest['flag_ack']) == 1)
            isInitiated = (int(digest['flag_initiated']) == 1)
            if not isRemap or (fid not in self.remoteDrainQueue and fid not in self.remoteDrainInit):
                continue
            if isInitiated and fid in self.remoteDrainInit:
                if self.DEBUG:
                    print("Drain initiated by FID", fid)
                self.remoteDrainInit.remove(fid)
                self.p4.Ingress.remap_check.delete(fid=fid, flag_initiated=0)
                bfrt.complete_operations()
            if isAck and fid in self.remoteDrainQueue:
                if self.DEBUG:
                    print("Drain complete by FID", fid)
                if fid in self.remoteDrainInit:
                    self.remoteDrainInit.remove(fid)
                if fid in self.remoteDrainQueue:
                    remaps = self.remoteDrainQueue[fid]
                    if len(self.remoteDrainQueue) == 1 and self.remoteDrainInitiator is not None:
                        self.resumeAllocation(self.remoteDrainInitiator, remaps)
                    self.remoteDrainQueue.pop(fid)
        return 0

    def initController(self):
        #bfrt.active.pipe.IngressDeparser.malloc_digest.callback_deregister()
        bfrt.active.pipe.IngressDeparser.malloc_digest.callback_register(self.onMallocRequest)
        bfrt.active.pipe.IngressDeparser.pipe.IngressDeparser.remap_digest.callback_register(self.onRemapAck)
        print("Digest handler registered for malloc/remap.")

    def monitor(self):
        # main control loop (for allocating, ageing, etc.)
        print("Starting monitor ... ")
        while self.watchdog:
            req = self.allocationRequests.get()
            self.allocate(req['fid'], req['progLen'], req['igLim'], req['accessIdx'], req['minDemand'])
            while req['fid'] in self.queue:
                pass

    def listen(self):
        self.monitorThread = threading.Thread(target=self.monitor)
        self.monitorThread.start()

# Custom settings.

def getReferenceOpcodes(basePath, sourceName):
    opcodes = set()
    bytecodeFile = os.path.join(basePath, "%s.apo" % sourceName)
    with open(bytecodeFile, 'rb') as f:
        data = list(f.read())
        f.close()
        i = 0
        while i < len(data):
            opcodes.add(data[i + 1])
            i = i + 2
    return opcodes

TOTAL_STAGES = 20
testMode = True
debug = True
restrictedInstructionSet = False
referenceProgram = "condition"
demoApps = [{
    'fid'       : 1,
    'idx'       : [3, 6, 9],
    'iglim'     : 8,
    'applen'    : 12,
    'mindemand' : [1, 1, 1]
}]

customInstructions = None
if restrictedInstructionSet:
    customInstructions = getReferenceOpcodes(refPath, referenceProgram)

controller = ActiveP4Controller(custom=customInstructions, basePath=basePath)

controller.clear_all()
controller.installControlEntries()
controller.installForwardingTableEntries(config=config['IPCONFIG'])
controller.createSidToPortMapping()
controller.setMirrorSessions()
controller.installInstructionTableEntries()

if testMode:
    num_indices = 65536
    for i in range(0, num_indices):
        #bfrt.active.pipe.Ingress.heap_s4.add(REGISTER_INDEX=i, f1=i)
        #bfrt.active.pipe.Ingress.heap_s9.add(REGISTER_INDEX=i, f1=3)
        pass
    for app in demoApps:
        controller.allocate(app['fid'], app['applen'], app['iglim'], app['idx'], app['mindemand'])
        pass
    
controller.initController()
controller.listen()

#controller.getTrafficCounters(fids)
#controller.resetTrafficCounters()