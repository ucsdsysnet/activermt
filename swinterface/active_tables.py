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
        self.NUM_STEPS          = 11
        self.MAX_FIDS           = 4

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

        self.loadPortMappings()

    def loadPortMappings(self):
        mapping_file = os.environ['OPERA_MAPPING_PATH'] if 'OPERA_MAPPING_PATH' in os.environ else '/tmp/dp_mappings_identity.csv'
        print "using mapping file: %s" % mapping_file
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
            'MEM_RST'           : "memory_%d_reset"
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
            'DROP'              : "drop",
            'GOTO_AUX'          : "goto_aux",
            'REVMIN'            : "min_mbr2_mbr",
            'MIN'               : "min_mbr_mbr2",
            'MARK_PACKET'       : "mark_packet",
            'COPY_MAR_MBR'      : "copy_mbr_mar",
            'COPY_MBR_MAR'      : "copy_mar_mbr"
        }
        self.OPS_BRANCHING = {
            'CJUMP'         : "jump_%d",
            'CJUMPI'        : "jump_%d",
            'DO'            : "jump_%d",
            'WHILE'         : "loop_end"
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

    def addForwardTableEntry(self, addr, port, pfx=32, flagAux=0, flagAck=0, flagRedirect=0):
        p4_pd.forward_table_add_with_setegr(
            p4_pd.forward_match_spec_t(
                flagAux,
                flagAck,
                flagRedirect,
                ipv4Addr_to_i32(addr), 
                pfx
            ),
            p4_pd.setegr_action_spec_t(self.dpmap[port])
        )

    def addBackwardTableEntry(self, addr, port):
        p4_pd.backward_table_add_with_setrts(
            p4_pd.backward_match_spec_t(
                ipv4Addr_to_i32(addr)
            ),
            p4_pd.setrts_action_spec_t(port)
        )

    def addResourcesTableEntry(self, fid):
        p4_pd.resources_table_add_with_set_quota(
            p4_pd.resources_match_spec_t(
                as_fid=fid
            ),
            p4_pd.set_quota_action_spec_t(
                self.QUOTAS_HORZ[fid][0], 
                self.QUOTAS_HORZ[fid][1], 
                5 # number of cycles
            ),
            p4_pd.bytes_meter_spec_t(self.CIR_KBPS, self.CBS_KBITS, self.PIR_CBPS, self.PBS_KBITS, False)
        )

    def addProgressTableEntry(self, action, mirrorPort=None, skipped=0, complete=0, duplicate=0, flagRts=0, flagAux=0):
        cmd = '''p4_pd.progress_table_add_with_%s(
            p4_pd.progress_match_spec_t(
                as_flag_rts=%d,
                as_flag_aux=%d, 
                meta_skipped=%d, 
                meta_complete=%d, 
                meta_duplicate=%d,
                meta_cycles_start=1,
                meta_cycles_end=hex_to_byte(0xFF)
            ), 
            1%s
        )''' % (
            action, 
            flagRts,
            flagAux, 
            skipped, 
            complete, 
            duplicate,  
            ',p4_pd.%s_action_spec_t(%d)' % (action, mirrorPort) if mirrorPort is not None else ''
        )
        exec(cmd)

    def addControlTableEntries(self, enableTrafficMonitor=False, enableResourceAllocator=False):
        p4_pd.check_completion_table_add_with_passthru(
            p4_pd.check_completion_match_spec_t(
                1
            )
        )
        if enableTrafficMonitor:
            p4_pd.filter_meter_table_add_with_dofilter_meter(
                p4_pd.filter_meter_match_spec_t(
                    meta_color=2
                )
            )
            p4_pd.filter_meter_table_add_with_dofilter_meter(
                p4_pd.filter_meter_match_spec_t(
                    meta_color=3
                )
            )
        p4_pd.monitor_table_add_with_report(
            p4_pd.monitor_match_spec_t(
                meta_digest=1
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
        p4_pd.resources_set_default_action_passthru(
            p4_pd.bytes_meter_spec_t(self.CIR_KBPS, self.CBS_KBITS, self.PIR_CBPS, self.PBS_KBITS, False)
        )
        p4_pd.cycleupdate_set_default_action_update_cycles()
        p4_pd.check_alloc_status_table_add_with_dofilter_alloc(
            p4_pd.check_alloc_status_match_spec_t(
                as_flag_reqalloc=1
            )
        )
        if enableResourceAllocator:
            p4_pd.memalloc_table_add_with_request_allocation(
                p4_pd.memalloc_match_spec_t(
                    as_flag_reqalloc=1,
                    meta_alloc_init=1
                )
            )

    def addExecuteTableEntry(self, fid, action, opcode, isDisabled=0, mbrStart=0, mbrEnd=65535, port=-1, memStart = 0, memEnd = 65535):
        if isDisabled == self.ENABLED:
            disabledStart = 0
            disabledEnd = 0
        elif isDisabled == self.DISABLED_SOFT:
            disabledStart = 1
            disabledEnd = 1
        else:
            disabledStart = 2
            disabledEnd = 3       
        mbrStart = 'hex_to_i16(0x%x)' % mbrStart
        mbrEnd = 'hex_to_i16(0x%x)' % mbrEnd
        memStart = 'hex_to_i16(0x%x)' % memStart
        memEnd = 'hex_to_i16(0x%x)' % memEnd
        actionSpec = (', p4_pd.set_port_action_spec_t(%d)' % port) if port >= 0 else ''
        cmd = '''p4_pd.execute_%d_table_add_with_%s(
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
            1%s
        )'''
        for stageId in range(1, self.NUM_STEPS + 1):
            action_stage = (action % stageId) if ('%d' in action) else action
            exec(cmd % (
                    stageId, action_stage, 
                    stageId, 
                    stageId - 1, opcode, 
                    disabledStart, disabledEnd, 
                    mbrStart, mbrEnd, 
                    1, stageId, stageId, 11,
                    memStart, memEnd,
                    fid,
                    actionSpec
                )
            )
    
    def addMemoryOpEntry(self, op, fid, isDisabled=0, mbrStart=0, mbrEnd=65535):
        memStart = self.QUOTAS_VERT[fid][0]
        memEnd = self.QUOTAS_VERT[fid][1]
        if memStart > 0:
            self.addExecuteTableEntry(fid, self.OPS_MEMACCESS[op], self.OPCODES[op], isDisabled, mbrStart, mbrEnd, memStart=0, memEnd=memStart-1)
        if memEnd < 65535:
            self.addExecuteTableEntry(fid, self.OPS_MEMACCESS[op], self.OPCODES[op], isDisabled, mbrStart, mbrEnd, memStart=memEnd+1, memEnd=65535)
        self.addExecuteTableEntry(fid, self.OPS_MEMACCESS[op], self.OPCODES[op], isDisabled, mbrStart, mbrEnd, memStart=memStart, memEnd=memEnd)

    def addMemoryOperations(self, fid):
        for op in self.OPS_MEMACCESS:
            self.addMemoryOpEntry(op, fid)
            self.addMemoryOpEntry(op, fid, isDisabled=self.DISABLED_HARD)

    def addProceedTableEntries(self):
        for stageId in range(1, self.NUM_STEPS + 1):
            exec('''p4_pd.proceed_%d_table_add_with_step_%d(
                p4_pd.proceed_%d_match_spec_t(
                    meta_loop=0
                )
            )''' % (stageId, stageId, stageId))

    def addDefaultOps(self):
        for op in self.OPS_DEFAULT:
            for fid in self.FIDS:
                self.addExecuteTableEntry(fid, self.OPS_DEFAULT[op], self.OPCODES[op])
                self.addExecuteTableEntry(fid, self.ACTION_SKIP, self.OPCODES[op], isDisabled=self.DISABLED_HARD)

    def addBranchingOps(self):
        for fid in self.FIDS:
            for op in self.OPS_BRANCHING:
                if op == 'CJUMP':
                    self.addExecuteTableEntry(fid, self.OPS_BRANCHING[op], self.OPCODES[op], mbrStart=1)
                    self.addExecuteTableEntry(fid, self.ACTION_SKIP, self.OPCODES[op], mbrEnd=0)
                else:
                    self.addExecuteTableEntry(fid, self.OPS_BRANCHING[op], self.OPCODES[op], mbrEnd=0)
                    self.addExecuteTableEntry(fid, self.ACTION_SKIP, self.OPCODES[op], mbrStart=1)
                self.addExecuteTableEntry(fid, self.ACTION_REJOIN, self.OPCODES[op], isDisabled=self.DISABLED_HARD)
            self.addExecuteTableEntry(fid, self.ACTION_REJOIN, 0, isDisabled=self.DISABLED_HARD)

opcodeLocation = '../config/opcodes.csv'

updater = ActiveP4TableUpdater()

updater.loadOpcodes(opcodeLocation)
updater.addFIDs()
updater.mapActions()

updater.addProceedTableEntries()
updater.addDefaultOps()
updater.addBranchingOps()

mirror_maps = {
    1   : 4,
    2   : 8,
    3   : 12,
    4   : 16
}

updater.createMirrorSessions(mirror_maps)

ip_dsts = {
    "10.0.0.1"      : 0, 
    "10.0.0.2"      : 4,
    "192.168.0.1"   : 4,
    "192.168.1.1"   : 0
}
mirror_ids = {
    "10.0.0.1"      : 6, 
    "10.0.0.2"      : 5,
    "192.168.0.1"   : 5, 
    "192.168.1.1"   : 6
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
    updater.addForwardTableEntry(dst, ip_dsts[dst])
    updater.addForwardTableEntry(dst, ip_dsts[dst], flagAck=1)
    updater.addForwardTableEntry(dst, ip_dsts[dst], flagAux=1)
    updater.addBackwardTableEntry(dst, mirror_ids[dst])
updater.addForwardTableEntry('0.0.0.0', 8, flagRedirect=1)

updater.addProgressTableEntry('cycle', mirrorPort=5)
updater.addProgressTableEntry('cycle_clone', mirrorPort=5, duplicate=1)
updater.addProgressTableEntry('cycle', mirrorPort=5, flagRts=1)
updater.addProgressTableEntry('cycle_clone', mirrorPort=5, flagRts=1, duplicate=1)
updater.addProgressTableEntry('cycle', mirrorPort=5, flagAux=1)
updater.addProgressTableEntry('cycle_clone', mirrorPort=5, flagAux=1, duplicate=1)
updater.addProgressTableEntry('cycle_aux', mirrorPort=5, skipped=1)
updater.addProgressTableEntry('cycle_clone_aux', mirrorPort=5, skipped=1, duplicate=1)
updater.addProgressTableEntry('cycle_redirect', flagRts=1, complete=1)

updater.addControlTableEntries()

updater.addMemoryOperations(10)
updater.addResourcesTableEntry(10)

conn_mgr.complete_operations()

print "TABLE CONFIGURATION COMPLETE!"

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