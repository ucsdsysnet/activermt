import json
import os

clear_all()

class ActiveP4TableUpdater:

    def __init__(self):
        self.FLAG_NONE          = 0         
        self.FLAG_REDIRECT      = 1
        self.FLAG_IGCLONE       = 2
        self.FLAG_BYPASS        = 3
        self.FLAG_RTS           = 5
        self.FLAG_AUX           = 8
        self.FLAG_ACK           = 0xFF
        self.MBR_MIN            = 0
        self.MBR_MAX            = 0xFFFF
        self.ENABLED            = 0
        self.DISABLED_SOFT      = 1
        self.DISABLED_HARD      = 2
        self.NUM_STEPS          = 17
        self.EG_START           = 7
        self.MAX_FIDS           = 4
        self.MAX_CYCLES         = 32

        self.CBS_KBITS          = 5
        self.PIR_CBPS           = 5
        self.CIR_KBPS           = 1
        self.PBS_KBITS          = 5

        self.OPCODES            = {}
        self.FIDS               = {}
        self.QUOTAS_HORZ        = {}
        self.QUOTAS_VERT        = {}
        self.OPS_DEFAULT        = {}
        self.OPS_MEMACCESS      = {}
        self.OPS_BRANCHING      = {}
        self.dpmap              = {}
        self.ACTION_SKIP        = 'skip'
        self.ACTION_REJOIN      = 'attempt_rejoin_%d'
        self.ACTION_RESUME      = 'enable_execution'

        self.entries            = []

        self.loadPortMappings()

    def loadPortMappings(self):
        mapping_file = os.environ['OPERA_MAPPING_PATH'] if 'OPERA_MAPPING_PATH' in os.environ else '/tmp/dp_mappings_identity.csv'
        print("using mapping file: %s" % mapping_file)
        with open(mapping_file, 'r') as f:
            lines = f.read().strip().splitlines()
            for l in lines:
                row = l.split(",")
                self.dpmap[int(row[0])] = int(row[1])
            f.close()

    def loadOpcodes(self, opcodeLocation):
        opcodeList = open(opcodeLocation).read().strip().splitlines()
        for id in range(0, len(opcodeList)):
            self.OPCODES[ opcodeList[id] ] = id + 1

    def addFIDs(self):
        for id in range(0, self.MAX_FIDS):
            fid  = id + 1
            self.FIDS[fid] = 'function_%d' % fid
        self.FIDS[10] = 'mgmt_func'
        self.QUOTAS_HORZ[10] = (1, self.NUM_STEPS)
        self.QUOTAS_VERT[10] = (0, 65535)

    def mapActions(self):
        self.OPS_MEMACCESS = {
            'MEM_READ'          : "memory_%d_read",
            'MEM_WRITE'         : "memory_%d_write",
            'COUNTER_RMW'       : "counter_%d_rmw",
            'MEM_SUB'           : "memory_%d_sub"
        }
        self.OPS_DEFAULT = {
            # stagewise
            'MAR_LOAD'          : "mar_load_%d",
            'MBR_ADD'           : "mbr_add_%d",
            'UJUMP'             : "jump_%d",
            'MBR_LOAD'          : "mbr_load_%d",
            'MBR2_LOAD'         : "mbr2_load_%d",
            'MAR_ADD'           : "mar_add_%d",
            'HASHMBR'           : "hashmar_%d",
            'BIT_AND_MBR'       : "bit_and_mbr_%d",
            'BIT_AND_MAR'       : "bit_and_mar_%d",
            'MBR_EQUALS_ARG'    : "mbr_equals_%d",
            # generic    
            'RETURN'            : "complete",
            'NOP'               : "skip",
            'LOOP_INIT'         : "loop_init",
            'COPY_MBR_MBR2'     : "copy_mbr_mbr2",
            'COPY_MBR2_MBR'     : "copy_mbr2_mbr",
            'ACC_LOAD'          : "acc_load",
            'ACC2_LOAD'         : "acc2_load",
            'DUPLICATE'         : "duplicate",
            'ENABLE_EXEC'       : "enable_execution",
            'RTS'               : "return_to_sender",
            'DROPIG'            : "drop_ig",
            'DROPEG'            : "drop_eg",
            'GOTO_AUX'          : "goto_aux",
            'REVMIN'            : "min_mbr2_mbr",
            'MIN'               : "min_mbr_mbr2",
            'MARK_PACKET'       : "mark_packet",
            'COPY_MAR_MBR'      : "copy_mbr_mar",
            'COPY_MBR_MAR'      : "copy_mar_mbr",
            'MBR_EQUALS_MBR2'   : "mbr_equals_mbr2",
            'BIT_AND_MAR_MBR'   : "bit_and_mar_mbr",
            'MAR_ADD_MBR'       : "mar_add_mbr",
            'LOAD_5TUPLE'       : "load_hashlist_5tuple",
            'HASH_GENERIC'      : "hash_generic",
            'HASHACC2'          : "hash_acc2",
            'LOAD_FROM_ACC'     : "acc_to_mbr",
            'RTSI'              : "rts_addr"
        }
        self.EG_ONLY = [ self.OPCODES[x] for x in [ 'LOAD_5TUPLE', 'HASH_GENERIC', 'DROPEG', 'RTS', 'SET_PORT', 'DUPLICATE' ] ]
        self.IG_ONLY = [ self.OPCODES[x] for x in [ 'DROPIG', 'RTSI', 'HASHACC2' ] ]
        self.OPS_BRANCHING = {
            'CJUMP'         : "jump_%d",
            'CJUMPI'        : "jump_%d",
            'DO'            : "jump_%d",
            'WHILE'         : "loop_end",
            'CRET'          : "complete",
            'CRTSI'         : "rts_addr" 
        }

    def createMirrorSessions(self, mirror_maps):
        for m in mirror_maps:
            mirror.session_create(
                mirror.MirrorSessionInfo_t(
                    mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
                    direction=mirror.Direction_e.PD_DIR_BOTH,
                    mir_id=m,
                    egr_port=self.dpmap[mirror_maps[m]], egr_port_v=True,
                    max_pkt_len=16384))

        mirror.session_create(
            mirror.MirrorSessionInfo_t(
                mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
                direction=mirror.Direction_e.PD_DIR_BOTH,
                mir_id=5,
                egr_port=self.dpmap[4], egr_port_v=True,
                max_pkt_len=16384))

        mirror.session_create(
            mirror.MirrorSessionInfo_t(
                mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
                direction=mirror.Direction_e.PD_DIR_BOTH,
                mir_id=6,
                egr_port=self.dpmap[0], egr_port_v=True,
                max_pkt_len=16384))

    def addForwardTableEntry(self, addr, port, mirror_spec, pfx=32, flagAux=0, flagAck=0, flagRedirect=0):
        p4_pd.forward_table_add_with_setegr(
            p4_pd.forward_match_spec_t(
                ipv4Addr_to_i32(addr), 
                pfx
            ),
            p4_pd.setegr_action_spec_t(self.dpmap[port], mirror_spec)
        )
        p4_pd.fwdparams_table_add_with_setcycleparams(
            p4_pd.fwdparams_match_spec_t(
                flagAux,
                flagAck,
                flagRedirect,
                ipv4Addr_to_i32(addr), 
                pfx
            ),
            p4_pd.setcycleparams_action_spec_t(self.dpmap[port], mirror_spec)
        )

    def addBackwardTableEntry(self, addr, port, pfx=32):
        p4_pd.backward_table_add_with_setrts(
            p4_pd.backward_match_spec_t(
                ipv4Addr_to_i32(addr),
                pfx
            ),
            p4_pd.setrts_action_spec_t(port)
        )

    def addResourcesTableEntry(self, fid=10, stageStart=1, stageEnd=11, cycles=1, freqStart=0, freqEnd=65535):
        p4_pd.preplimit_table_add_with_seed(
            p4_pd.preplimit_match_spec_t(
                as_fid=fid
            )
        )
        p4_pd.resources_table_add_with_set_quota(
            p4_pd.resources_match_spec_t(
                as_fid=fid,
                as_freq_start=hex_to_i16(freqStart),
                as_freq_end=hex_to_i16(freqEnd)
            ),
            1,
            p4_pd.set_quota_action_spec_t(
                stageStart, 
                stageEnd, 
                cycles
            )
        )
        print("added resource quota")

    def addProgressTableEntry(self, action, skipped=0, complete=0, duplicate=0, flagRts=0, flagAux=0, minCycles=1):
        cmd = '''p4_pd.progress_table_add_with_%s(
            p4_pd.progress_match_spec_t(
                as_flag_rts=%d,
                as_flag_aux=%d, 
                meta_skipped=%d, 
                meta_complete=%d, 
                meta_duplicate=%d,
                meta_cycles_start=%d,
                meta_cycles_end=hex_to_byte(0xFF)
            ), 
            1
        )''' % (
            action, 
            flagRts,
            flagAux, 
            skipped, 
            complete, 
            duplicate,
            minCycles
        )
        exec(cmd)

    def addControlTableEntries(self, enableTrafficMonitor=False, enableResourceAllocator=True):
        p4_pd.check_completion_table_add_with_passthru(
            p4_pd.check_completion_match_spec_t(
                1
            )
        )
        p4_pd.lenupdate_table_add_with_update_lengths(
            p4_pd.lenupdate_match_spec_t(
                meta_rts=0,
                meta_complete=1
            )
        )
        p4_pd.lenupdate_table_add_with_update_burnt(
            p4_pd.lenupdate_match_spec_t(
                meta_rts=1,
                meta_complete=1
            )
        )
        p4_pd.resources_set_default_action_passthru()
        p4_pd.cycleupdate_set_default_action_update_cycles()
        p4_pd.preload_table_add_with_preload_mbr(
            p4_pd.preload_match_spec_t(
                as_flag_exceeded=1
            )
        )

    def addExecuteTableEntry(self, fid, action, opcode, isDisabled=0, mbrStart=0, mbrEnd=65535, port=-1, memStart = 0, memEnd = 65535):    
        mbrStart = 'hex_to_i16(0x%x)' % mbrStart
        mbrEnd = 'hex_to_i16(0x%x)' % mbrEnd
        memStart = 'hex_to_i16(0x%x)' % memStart
        memEnd = 'hex_to_i16(0x%x)' % memEnd
        actionSpec = (', p4_pd.set_port_action_spec_t(%d)' % port) if port >= 0 else ''
        cmd = '''p4_pd.execute_%d_table_add_with_%s(
            p4_pd.execute_%d_match_spec_t(
                ap_%d__opcode=%d,
                as_fid=%d, 
                meta_complete=0,
                meta_disabled=%d, 
                meta_mbr_start=%s,
                meta_mbr_end=%s, 
                meta_mar_start=%s,
                meta_mar_end=%s
            ), 
            1%s
        )'''
        for i in range(1, self.NUM_STEPS + 1):
            stageId = i
            action_stage = (action % stageId) if ('%d' in action) else action
            if opcode in self.EG_ONLY and i < self.EG_START:
                continue
            elif opcode in self.IG_ONLY and i >= self.EG_START:
                continue
            exec(cmd % (
                    stageId, action_stage, 
                    stageId, 
                    (stageId - 1 if i < 7 else i - 7), opcode, 
                    fid,
                    isDisabled,
                    mbrStart, mbrEnd, 
                    memStart, memEnd,
                    actionSpec
                )
            )
            self.entries.append("EXECUTE:%d: %s,%d,%d,%d,%s,%s,%s,%s,%d" % (stageId, action, fid, opcode, isDisabled, mbrStart, mbrEnd, memStart, memEnd, port))
    
    def addMemoryOpEntry(self, op, fid, isDisabled=0, mbrStart=0, mbrEnd=65535):
        if isDisabled == self.ENABLED:
            memStart = self.QUOTAS_VERT[fid][0]
            memEnd = self.QUOTAS_VERT[fid][1]
            if memStart > 0:
                self.addExecuteTableEntry(fid, self.OPS_MEMACCESS[op], self.OPCODES[op], isDisabled=isDisabled, mbrStart=mbrStart, mbrEnd=mbrEnd, memStart=0, memEnd=memStart-1)
            if memEnd < 65535:
                self.addExecuteTableEntry(fid, self.OPS_MEMACCESS[op], self.OPCODES[op], isDisabled=isDisabled, mbrStart=mbrStart, mbrEnd=mbrEnd, memStart=memEnd+1, memEnd=65535)
            self.addExecuteTableEntry(fid, self.OPS_MEMACCESS[op], self.OPCODES[op], isDisabled=isDisabled, mbrStart=mbrStart, mbrEnd=mbrEnd, memStart=memStart, memEnd=memEnd)
        else:
            self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], isDisabled)

    def addMemoryOperations(self, fid):
        for op in self.OPS_MEMACCESS:
            self.addMemoryOpEntry(op, fid)
            self.addMemoryOpEntry(op, fid, isDisabled=self.DISABLED_HARD)

    def addProceedTableEntries(self):
        for stageId in range(1, self.NUM_STEPS + 1):
            exec('''p4_pd.proceed_%d_table_add_with_step_%d(
                p4_pd.proceed_%d_match_spec_t(
                    meta_complete=0,
                    meta_loop=0
                )
            )''' % (stageId, stageId, stageId))

    def addDefaultOps(self):
        for op in self.OPS_DEFAULT:
            for fid in self.FIDS:
                self.addExecuteTableEntry(fid, self.OPS_DEFAULT[op], self.OPCODES[op])
                self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], isDisabled=self.DISABLED_HARD)

    def addDisabledOps(self):
        for fid in range(1, self.MAX_FIDS + 1):
            for op in self.OPS_MEMACCESS:
                self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], self.DISABLED_HARD)
            for op in self.OPS_DEFAULT:
                self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], self.DISABLED_HARD)
            for op in self.OPS_BRANCHING:
                self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], self.DISABLED_HARD)

    def addBranchingOps(self):
        for fid in self.FIDS:
            for op in self.OPS_BRANCHING:
                if op == 'CJUMP' or op == 'CRET' or op == 'CJUMPI':
                    self.addExecuteTableEntry(fid, self.OPS_BRANCHING[op], self.OPCODES[op], mbrStart=1)
                    self.addExecuteTableEntry(fid, self.ACTION_SKIP, self.OPCODES[op], mbrEnd=0)
                else:
                    self.addExecuteTableEntry(fid, self.OPS_BRANCHING[op], self.OPCODES[op], mbrEnd=0)
                    self.addExecuteTableEntry(fid, self.ACTION_SKIP, self.OPCODES[op], mbrStart=1)
                self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], isDisabled=self.DISABLED_HARD)
            self.addExecuteTableEntry(fid, self.ACTION_REJOIN, 0, isDisabled=self.DISABLED_HARD)

opcodeLocation = '../config/opcodes.csv'

updater = ActiveP4TableUpdater()

"""mirror_maps = {
    1   : 4,
    2   : 8,
    3   : 12,
    4   : 16
}"""

mirror_maps = {}
NUM_SERVERS = 4
DEFAULT_MAP_LOCAL = 4
DEFAULT_MAP_HW = 0
for i in range(0, NUM_SERVERS):
    mirror_maps[i + 1] = DEFAULT_MAP_HW

updater.createMirrorSessions(mirror_maps)

updater.loadOpcodes(opcodeLocation)
updater.addFIDs()
updater.mapActions()

updater.addProceedTableEntries()
updater.addDefaultOps()
updater.addBranchingOps()
updater.addDisabledOps()

ip_dsts = {
    "10.0.0.1"      : 0, 
    "10.0.0.2"      : 4,
    "192.168.0.1"   : 0,
    "192.168.1.1"   : 4
}
mirror_ids = {
    "10.0.0.1"      : 6, 
    "10.0.0.2"      : 5,
    "192.168.0.1"   : 6, 
    "192.168.1.1"   : 5
}

mirror_end = 0x5

# SPECIAL INSTRUCTIONS 
for fid in updater.FIDS:
    updater.addExecuteTableEntry(fid, updater.ACTION_REJOIN, updater.OPCODES['SET_PORT'], isDisabled=updater.DISABLED_HARD)
    for p in mirror_maps:
        updater.addExecuteTableEntry(fid, 'set_port', updater.OPCODES['SET_PORT'], mbrStart=p, mbrEnd=p, port=p)
    updater.addExecuteTableEntry(fid, 'set_port', updater.OPCODES['SET_PORT'], mbrEnd=0, port=6)
    updater.addExecuteTableEntry(fid, updater.ACTION_SKIP, updater.OPCODES['SET_PORT'], mbrStart=mirror_end)
    updater.addExecuteTableEntry(fid, 'mark_packet', updater.OPCODES['MARK_IF'], mbrEnd=0)
    updater.addExecuteTableEntry(fid, updater.ACTION_SKIP, updater.OPCODES['MARK_IF'], mbrStart=1)

for dst in ip_dsts:
    updater.addForwardTableEntry(dst, ip_dsts[dst], mirror_ids[dst])
    #updater.addForwardTableEntry(dst, ip_dsts[dst], mirror_ids[dst], flagAck=1)
    #updater.addForwardTableEntry(dst, ip_dsts[dst], mirror_ids[dst], flagAux=1)
    updater.addBackwardTableEntry(dst, mirror_ids[dst])
#updater.addForwardTableEntry('0.0.0.0', 8, 2, flagRedirect=1)
updater.addForwardTableEntry('10.1.0.0', 4, 5, pfx=16)
updater.addBackwardTableEntry('10.1.0.0', 5, pfx=16)

updater.addProgressTableEntry('cycle')
updater.addProgressTableEntry('cycle_clone', duplicate=1)
#updater.addProgressTableEntry('cycle', flagRts=1)
updater.addProgressTableEntry('cycle_clone', flagRts=1, duplicate=1)
updater.addProgressTableEntry('cycle', flagAux=1)
updater.addProgressTableEntry('cycle_clone', flagAux=1, duplicate=1)
updater.addProgressTableEntry('cycle_aux', skipped=1)
updater.addProgressTableEntry('cycle_clone_aux', skipped=1, duplicate=1)
updater.addProgressTableEntry('cycle_redirect', flagRts=1, complete=1)
updater.addProgressTableEntry('cycle_redirect', flagRts=1)

updater.addControlTableEntries()

#updater.addMemoryOperations(10)
#updater.addResourcesTableEntry(fid=10, cycles=10)

conn_mgr.complete_operations()

with open("table-entries.txt", "w") as out:
    out.write("\n".join(updater.entries))
    out.close()

print("TABLE CONFIGURATION COMPLETE!")

"""for i in range(0, NUM_STEPS):
    stageId = i + 1
    REJOIN_ACTION = 'attempt_rejoin_%d' % stageId
    JUMP_ACTION = 'jump_%d' % stageId
    # cread/cwrite
    addExecuteTableEntry(stageId, 'memory_%d_write' % stageId, OPCODES['CMEM_WRITE'], ENABLED, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'memory_%d_read' % stageId, OPCODES['CMEM_READ'], ENABLED, 0, 0)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CMEM_READ'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CMEM_WRITE'], DISABLED_SOFT, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'enable_execution', OPCODES['ENABLE_EXEC'], DISABLED_SOFT, MBR_MIN, MBR_MAX)   
    # conditional return
    addExecuteTableEntry(stageId, 'complete', OPCODES['CRET'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CRET'], ENABLED, 0, 0)
    # conditional enable exec
    addExecuteTableEntry(stageId, JUMP_ACTION, OPCODES['C_ENABLE_EXEC'], DISABLED_SOFT, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['C_ENABLE_EXEC'], ENABLED, 0, MBR_MAX)"""
