import os
import math
import sys
import time
import inspect
import threading
import logging

VERSION = "%d.%d" % (sys.version_info.major, sys.version_info.minor)
sys.path.insert(0, '/usr/local/lib/python%s/dist-packages' % VERSION)

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
    global logging
    global IPAddress

    REG_MAX = 0xFFFFF
    DEBUG = True

    def __init__(self, custom=None, basePath=""):
        self.p4 = bfrt.active.pipe
        self.watchdog = True
        self.num_stages_ingress = 10
        self.num_stages_egress = 10
        self.max_constraints = 8
        self.num_stages_total = self.num_stages_ingress + self.num_stages_egress
        self.max_stage_sharing = 8
        self.max_iter = 100
        self.recirculation_enabled = True
        self.allocation_shared = False
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
        self.queue = []
        self.allocation = np.zeros((self.max_stage_sharing, self.num_stages_total))
        self.active = []
        self.installed = []

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
        with open(os.path.join(self.base_path, 'config', 'arp_table.csv')) as f:
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
                fid = entry.key.get(b'hdr.ih.fid')
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

    def updateAllocationTables(self, fid, memIdx):

        stageWiseAlloc = np.sum(self.allocation, axis=0)

        alloc = []
        for i in range(0, len(memIdx)):
            k = memIdx[i]
            # split shared stages
            if stageWiseAlloc[k] > 0:
                occupancy = np.unique(self.allocation[ : , k])
                occupancy.append(fid)
                blockSize = np.round(self.max_stage_sharing / len(occupancy))
                offset = 0
                for j in range(0, len(occupancy)):
                    limit = min(offset + blockSize, self.max_stage_sharing)
                    memStart = offset * 8192
                    memSize = (limit - offset) * 8192 - 1
                    for l in range(offset, limit):
                        self.occupancy[l, k] = occupancy[j]
                    alloc.append((occupancy[j], k, memStart, memSize))
            # allocate exclusive stages
            else:
                for j in range(0, self.max_stage_sharing):
                    self.allocation[j, k] = fid
                alloc.append((fid, k, 0, 0xFFFF))
        
        allocMap = {}
        stagesAllocated = {}
        for a in alloc:
            if a[1] not in allocMap:
                allocMap[a[1]] = []
            allocMap[a[1]].append(a)
            if a[0] not in stagesAllocated:
                stagesAllocated[a[0]] = []
            stageId = a[1] % self.num_stages_ingress
            stagesAllocated[a[0]].append(stageId)

        if self.DEBUG:
            print(allocMap)
            print(self.allocation)

        egIgMap = {}

        # update instruction tables
        for stage in allocMap:
            stageId = stage - self.num_stages_ingress if stage >= self.num_stages_ingress else stage
            isIg = stage < self.num_stages_ingress
            gress = self.p4.Ingress if isIg else self.p4.Egress
            if self.allocation_shared:
                entries = self.fetchMemoryAccessEntries(stageId, gress)
                # TODO implement sharing - runtime reallocation protocol.
                for f in entries:
                    if f != fid:
                        # notify apps (instead of snatching memory).
                        pass
            if stageId not in egIgMap:
                egIgMap[stageId] = {}
            for salloc in allocMap[stage]:
                sfid = salloc[0]
                memStart = salloc[2]
                memEnd = memStart + salloc[3] - 1
                for pnemonic in self.opcode_action:
                    act = self.opcode_action[pnemonic]
                    if act['memory']:
                        self.installInstructionTableEntry(sfid, act, gress, stageId, memStart=memStart, memEnd=memEnd)
                if sfid not in egIgMap[stageId]:
                    egIgMap[stageId][sfid] = {
                        'ig'    : None,
                        'eg'    : None
                    }
                gressKey = 'ig' if isIg else 'eg'
                egIgMap[stageId][sfid][gressKey] = (memStart, salloc[3])

        # update allocation tables
        for stageId in egIgMap:
            allocTable = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % stageId)
            actionSpec = getattr(allocTable, 'add_with_get_allocation_s%d' % stageId)
            for sfid in egIgMap[stageId]:
                igOffset = 0 if egIgMap[stageId][sfid]['ig'] is None else egIgMap[stageId][sfid]['ig'][0]
                igSize = 0 if egIgMap[stageId][sfid]['ig'] is None else egIgMap[stageId][sfid]['ig'][1]
                egOffset = 0 if egIgMap[stageId][sfid]['eg'] is None else egIgMap[stageId][sfid]['eg'][0]
                egSize = 0 if egIgMap[stageId][sfid]['eg'] is None else egIgMap[stageId][sfid]['eg'][1]
                actionSpec(fid=sfid, flag_allocated=1, offset_ig=igOffset, size_ig=igSize, offset_eg=egOffset, size_eg=egSize)

        for sfid in stagesAllocated:
            for stageId in range(0, self.num_stages_ingress):
                allocTable = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % stageId)
                actionSpec = getattr(allocTable, 'add_with_default_allocation_s%d' % stageId)
                if stageId not in stagesAllocated[sfid]:
                    actionSpec(fid=sfid, flag_allocated=1)

        return alloc

    def allocatorRandomized(self, constr):

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
        
        return (memIdx, allocationValid, numTrialsOuter, numTrialsInner)

    def deallocate(self, fid):

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
            if fid in entries:
                for entry in entries[fid]:
                    entry.remove()

        allocreqs = self.p4.Ingress.allocation.dump(return_ents=True)
        for entry in allocreqs:
            afid = entry.key.get(b'hdr.ih.fid')
            if afid == fid:
                entry.remove()

        bfrt.complete_operations()

    def allocate(self, fid, constr):

        if fid in self.queue or fid in self.active:
            return

        tsOverallStart = time.time()

        self.queue.append(fid)

        if self.DEBUG:
            print("Attempting allocation for FID", fid)

        self.p4.Ingress.allocation.add_with_pending(fid=fid, flag_reqalloc=2)
        bfrt.complete_operations()

        if self.DEBUG:
            print("Constraints", constr)

        tsAllocationStart = time.time()

        (memIdx, allocationValid, numTrialsOuter, numTrialsInner) = self.allocatorRandomized(constr)
            
        tsAllocationStop = time.time()

        elapsedAllocation = tsAllocationStop - tsAllocationStart
        if self.DEBUG:
            print("Elapsed (allocation) time", elapsedAllocation)

        if not self.allocation_shared and not allocationValid:
            self.p4.Ingress.allocation.delete(fid=fid, flag_reqalloc=2)
            bfrt.complete_operations()
            self.queue.remove(fid)
            if self.DEBUG:
                print("Allocation failed for FID", fid)
            return 

        self.updateAllocationTables(fid, memIdx)
        self.addQuotas(fid, recirculate=True)

        self.p4.Ingress.allocation.delete(fid=fid, flag_reqalloc=2)
        self.p4.Ingress.allocation.add_with_allocated(fid=fid, flag_reqalloc=2)
        bfrt.complete_operations()

        self.active.append(fid)
        self.queue.remove(fid)

        tsOverallStop = time.time()

        elapsedOverall = tsOverallStop - tsOverallStart
        if self.DEBUG:
            print("Elapsed (overall) time", elapsedOverall)

        # stats
        utilization = np.sum(self.allocation > 0) / (self.max_stage_sharing * self.num_stages_total)
        occupiedFIDs = np.unique(self.allocation)
        numOccupancy = len(occupiedFIDs) if 0 not in occupiedFIDs else len(occupiedFIDs) - 1
        logging.info("[ELAPSED] allocation %f overall %f utilization %f occupancy %d iters %d trials %d", elapsedAllocation, elapsedOverall, utilization, numOccupancy, numTrialsOuter, numTrialsInner)

    def onMallocRequest(self, dev_id, pipe_id, directon, parser_id, session, msg):
        for digest in msg:
            fid = digest['fid']
            constr = []
            for i in range(0, self.max_constraints):
                lb = digest['constr_lb_%d' % i]
                ub = digest['constr_ub_%d' % i]
                ms = digest['constr_ms_%d' % i]
                if lb > 0 and ub > 0 and ms  > 0:
                    constr.append((lb, ub, ms))
            th = threading.Thread(target=self.allocate, args=(fid, constr,))
            th.start()
        return 0

    def initController(self):
        #bfrt.active.pipe.IngressDeparser.malloc_digest.callback_deregister()
        bfrt.active.pipe.IngressDeparser.malloc_digest.callback_register(self.onMallocRequest)
        print("Digest handler registered for malloc.")

    def monitor(self):
        # main control loop (for ageing, etc.)
        while self.watchdog:
            pass

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
testMode = False
restrictedInstructionSet = False
referenceProgram = "condition"
basePath = "/usr/local/home/rajdeepd/activep4"
#basePath = "/root/src/activep4-p416"
fids = [1]

customInstructions = None
if restrictedInstructionSet:
    customInstructions = getReferenceOpcodes("/usr/local/home/rajdeepd/activep4/apps/test", referenceProgram)

controller = ActiveP4Controller(custom=customInstructions, basePath=basePath)

controller.clear_all()
controller.installControlEntries()
controller.installForwardingTableEntries(config='default')
controller.createSidToPortMapping()
controller.setMirrorSessions()
controller.installInstructionTableEntries()

if testMode:
    memIdx = range(0, TOTAL_STAGES)
    for fid in fids:
        controller.updateAllocationTables(fid, memIdx)
        controller.addQuotas(fid, recirculate=True)
else:
    controller.initController()

#controller.getTrafficCounters(fids)
#controller.resetTrafficCounters()