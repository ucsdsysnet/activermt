import json
import os

clear_all()

FLAG_NONE       = 0         
FLAG_REDIRECT   = 1
FLAG_IGCLONE    = 2
FLAG_BYPASS     = 3
FLAG_RTS        = 5
FLAG_AUX        = 8
FLAG_ACK        = 0xFF

MBR_MIN         = 0
MBR_MAX         = 0xFFFF
ENABLED         = 0
DISABLED_SOFT   = 1
DISABLED_HARD   = 2

dpmap = {}
mapping_file = os.environ['OPERA_MAPPING_PATH'] if 'OPERA_MAPPING_PATH' in os.environ else '/tmp/dp_mappings_identity.csv'
print "using mapping file: %s" % mapping_file
with open(mapping_file, 'r') as f:
    lines = f.read().strip().splitlines()
    for l in lines:
        row = l.split(",")
        dpmap[int(row[0])] = int(row[1])
    f.close()

NUM_STEPS = 11
OPCODES = json.loads(open('./opcodes.json').read(), encoding='utf-8')
"""FIDS = {
    1   : 'unrestricted',
    2   : 'partial',
    3   : 'strict'
}
QUOTAS = {
    1   : (1, 11),
    2   : (1, 11),
    3   : (4, 5)
}
VERTICAL_QUOTAS = {
    1   : (0, 65535),
    2   : (0, 4095),
    3   : (4096, 8191)
}"""

FIDS = {}
QUOTAS = {}
VERTICAL_QUOTAS = {}
BLOCK_SIZE = 8192

for id in range(0, 8):
    fid  = id + 1
    FIDS[fid] = 'function_%d' % fid
    QUOTAS[fid] = (1, NUM_STEPS)
    VERTICAL_QUOTAS[fid] = (id * BLOCK_SIZE, fid * BLOCK_SIZE - 1)
FIDS[10] = 'mgmt_func'
QUOTAS[10] = (1, NUM_STEPS)
VERTICAL_QUOTAS[10] = (0, 65535)

ACTIONS = {
    'dependent'     : {
        'MAR_LOAD'          : "mar_load_%d",
        'MBR_ADD'           : "mbr_add_%d",
        'MEM_READ'          : "memory_%d_read",
        'MEM_WRITE'         : "memory_%d_write",
        'UJUMP'             : "jump_%d",
        'MBR_LOAD'          : "mbr_load_%d",
        'MBR_SUBTRACT'      : "mbr_subtract_%d",
        'BIT_AND_MBR_MAR'   : "bit_and_mbr_mar_%d",
        'MBR2_LOAD'         : "mbr2_load_%d",
        'MAR_EQUALS'        : "mar_equals_%d",
        'MAR_ADD'           : "mar_add_%d",
        'BIT_AND_MBR'       : "bit_and_mbr_%d",
        'COUNTER_RMW'       : "counter_%d_rmw",
        #'COUNTER_MINREAD'   : "lru_minread_%d",
        #'UPDATE_LRUTGT'     : "update_lru_tgt_%d",
        'MEM_RST'           : "memory_%d_reset"
    },
    'independent'   : {
        'RETURN'        : "complete",
        'NOP'           : "skip",
        'LOOP_INIT'     : "loop_init",
        #'COPY_MBR2_MBR' : "copy_mbr2_mbr",
        'ACC_LOAD'      : "acc_load",
        'ACC2_LOAD'     : "acc2_load",
        'MARK_PROCESSED': "mark_processed_packet",
        'DUPLICATE'     : "duplicate",
        'ENABLE_EXEC'   : "enable_execution",
        'RTS'           : "return_to_sender",
        'RANDOM_PORT'   : "get_random_port",
        #'HASH5TUPLE'    : "hash5tuple",
        #'HASHID'        : "hash_id",
        'DROP'          : "drop",
        'GOTO_AUX'      : "goto_aux",
        'HASH4K'        : "hashmar_4096",
        'HASH8K'        : "hashmar_8192"
    }, 
    'branch'        : {
        'CJUMP'         : "jump_%d",
        'CJUMPI'        : "jump_%d",
        'DO'            : "jump_%d",
        'WHILE'         : "loop_end"
    },
    'chain'         : {
        'CMEM_WRITE'    : "memory_%d_write",
        'CMEM_READ'     : "memory_%d_read"
    }
}

OPS_MEMACCESS = [
    "MEM_READ",
    "MEM_WRITE",
    "CMEM_WRITE",
    "CMEM_READ",
    "CCOUNT",
    "MEM_RST"
]
OPCODES_MEMACCESS = []
for op in OPS_MEMACCESS:
    OPCODES_MEMACCESS.append(OPCODES[op])

mirror_maps = {
    1   : 4,
    2   : 8,
    3   : 12,
    4   : 16
}

for m in mirror_maps:
    mirror.session_create(
        mirror.MirrorSessionInfo_t(
            mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
            direction=mirror.Direction_e.PD_DIR_BOTH,
            mir_id=m,
            egr_port=dpmap[mirror_maps[m]], egr_port_v=True,
            max_pkt_len=16384))

mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=5,
        egr_port=dpmap[4], egr_port_v=True,
        max_pkt_len=16384))
mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=6,
        egr_port=dpmap[0], egr_port_v=True,
        max_pkt_len=16384))

def addExecuteTableEntry(stageId, action, opcode, isDisabled, mbrStart, mbrEnd, port=-1, memStart=0, memEnd=65535):
    if isDisabled == ENABLED:
        disabledStart = 0
        disabledEnd = 0
    elif isDisabled == DISABLED_SOFT:
        disabledStart = 1
        disabledEnd = 1
    else:
        disabledStart = 2
        disabledEnd = 127       
    mbrStart = str(mbrStart) if mbrEnd > 0 else '0'
    mbrEnd = 'hex_to_i16(0xFFFF)' if mbrEnd == MBR_MAX else str(mbrEnd)
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
    for fid in FIDS:
        if opcode in OPCODES_MEMACCESS:
            pass
            """memStart = VERTICAL_QUOTAS[fid][0]
            memEnd = VERTICAL_QUOTAS[fid][1]
            if memStart > 0:
                lStart = 'hex_to_i16(0x0)'
                lEnd = 'hex_to_i16(0x%x)' % (memStart - 1)
                exec(cmd % (
                        stageId, 'memfault', stageId, 
                        stageId - 1, opcode, 
                        disabledStart, disabledEnd, 
                        mbrStart, mbrEnd, 
                        1, 11, 1, 11,
                        lStart, lEnd,
                        fid,
                        ''
                    )
                )
            if memEnd < 65535:
                rStart = 'hex_to_i16(0x%x)' % (memEnd + 1)
                rEnd = 'hex_to_i16(0xFFFF)'
                exec(cmd % (
                        stageId, 'memfault', stageId, 
                        stageId - 1, opcode, 
                        disabledStart, disabledEnd, 
                        mbrStart, mbrEnd, 
                        1, 11, 1, 11,
                        rStart, rEnd,
                        fid,
                        ''
                    )
                )
            memStart = 'hex_to_i16(0x%x)' % memStart
            memEnd = 'hex_to_i16(0x%x)' % memEnd
            exec(cmd % (
                    stageId, action, stageId, 
                    stageId - 1, opcode, 
                    disabledStart, disabledEnd, 
                    mbrStart, mbrEnd, 
                    1, stageId, stageId, 11,
                    memStart, memEnd,
                    fid,
                    actionSpec
                )
            )"""
        else:
            exec(cmd % (
                    stageId, action, stageId, 
                    stageId - 1, opcode, 
                    disabledStart, disabledEnd, 
                    mbrStart, mbrEnd, 
                    1, 11, 1, 11,
                    'hex_to_i16(0x0)', 'hex_to_i16(0xFFFF)',
                    fid,
                    actionSpec
                )
            )

mirror_end = 0x5

for i in range(0, NUM_STEPS):
    stageId = i + 1
    REJOIN_ACTION = 'attempt_rejoin_%d' % stageId
    JUMP_ACTION = 'jump_%d' % stageId
    exec('''p4_pd.proceed_%d_table_add_with_step_%d(
        p4_pd.proceed_%d_match_spec_t(
            meta_loop=0
        )
    )''' % (stageId, stageId, stageId))
    for action in ACTIONS['dependent']:
        addExecuteTableEntry(stageId, ACTIONS['dependent'][action] % stageId, OPCODES[action], ENABLED, MBR_MIN, MBR_MAX)
        addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES[action], DISABLED_HARD, MBR_MIN, MBR_MAX)
    for action in ACTIONS['independent']:
        addExecuteTableEntry(stageId, ACTIONS['independent'][action], OPCODES[action], ENABLED, MBR_MIN, MBR_MAX)
        addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES[action], DISABLED_HARD, MBR_MIN, MBR_MAX)
    # conditional jump
    addExecuteTableEntry(stageId, JUMP_ACTION, OPCODES['CJUMP'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CJUMP'], ENABLED, 0, 0)
    addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES['CJUMP'], DISABLED_HARD, MBR_MIN, MBR_MAX)
    # conditional jump inverse
    addExecuteTableEntry(stageId, JUMP_ACTION, OPCODES['CJUMPI'], ENABLED, 0, 0)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CJUMPI'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES['CJUMPI'], DISABLED_HARD, MBR_MIN, MBR_MAX)
    # do
    addExecuteTableEntry(stageId, JUMP_ACTION, OPCODES['DO'], ENABLED, 0, 0)
    addExecuteTableEntry(stageId, 'skip', OPCODES['DO'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES['DO'], DISABLED_HARD, MBR_MIN, MBR_MAX)
    # while
    addExecuteTableEntry(stageId, 'loop_end', OPCODES['WHILE'], ENABLED, 0, 0)
    addExecuteTableEntry(stageId, 'skip', OPCODES['WHILE'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES['WHILE'], DISABLED_HARD, MBR_MIN, MBR_MAX)
    # disabled nop
    addExecuteTableEntry(stageId, REJOIN_ACTION, 0, DISABLED_HARD, MBR_MIN, MBR_MAX)
    # cread/cwrite
    addExecuteTableEntry(stageId, 'memory_%d_write' % stageId, OPCODES['CMEM_WRITE'], ENABLED, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'memory_%d_read' % stageId, OPCODES['CMEM_READ'], ENABLED, 0, 0)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CMEM_READ'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CMEM_WRITE'], DISABLED_SOFT, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'enable_execution', OPCODES['ENABLE_EXEC'], DISABLED_SOFT, MBR_MIN, MBR_MAX)
    # setport
    addExecuteTableEntry(stageId, REJOIN_ACTION, OPCODES['SET_PORT'], DISABLED_HARD, MBR_MIN, MBR_MAX)
    for p in mirror_maps:
        addExecuteTableEntry(stageId, 'set_port', OPCODES['SET_PORT'], ENABLED, p, p, port=p)
    addExecuteTableEntry(stageId, 'set_port', OPCODES['SET_PORT'], ENABLED, 0, 0, port=6)
    addExecuteTableEntry(stageId, 'skip', OPCODES['SET_PORT'], ENABLED, mirror_end, MBR_MAX)
    
    # conditional return
    addExecuteTableEntry(stageId, 'complete', OPCODES['CRET'], ENABLED, 1, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CRET'], ENABLED, 0, 0)
    # conditional enable exec
    addExecuteTableEntry(stageId, JUMP_ACTION, OPCODES['C_ENABLE_EXEC'], DISABLED_SOFT, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['C_ENABLE_EXEC'], ENABLED, 0, MBR_MAX)
    """
    # conditional count
    addExecuteTableEntry(stageId, 'counter_%d_rmw' % stageId, OPCODES['CCOUNT'], ENABLED, MBR_MIN, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['CCOUNT'], ENABLED, 0, MBR_MAX)
    # read mincount
    addExecuteTableEntry(stageId, ACTIONS['dependent']['COUNTER_MINREAD'] % stageId, OPCODES['COUNTER_MINREAD'], False, 0, MBR_MAX)
    addExecuteTableEntry(stageId, 'skip', OPCODES['COUNTER_MINREAD'], True, 0, MBR_MAX)
    # update lru target
    addExecuteTableEntry(stageId, ACTIONS['dependent']['UPDATE_LRUTGT'] % stageId, OPCODES['UPDATE_LRUTGT'], False, 1, MBR_MAX)
    # purge memory
    exec("p4_pd.execute_%d_table_add_with_memory_%d_write(p4_pd.execute_%d_match_spec_t(ap_%d__opcode=%d, meta_disabled_start=0, meta_disabled_end=0, meta_mbr_start=0, meta_mbr_end=hex_to_i16(0xFFFF), meta_quota_start=%d, meta_quota_end=11, meta_complete=0, meta_lru_target_start=%d, meta_lru_target_end=%d), 1)" % (stageId, stageId, stageId, stageId - 1, OPCODES['LRU_PURGE'], stageId, stageId, stageId))
    if stageId > 1:
        exec("p4_pd.execute_%d_table_add_with_skip(p4_pd.execute_%d_match_spec_t(ap_%d__opcode=%d, meta_disabled_start=0, meta_disabled_end=0, meta_mbr_start=0, meta_mbr_end=hex_to_i16(0xFFFF), meta_quota_start=%d, meta_quota_end=11, meta_complete=0, meta_lru_target_start=%d, meta_lru_target_end=%d), 1)" % (stageId, stageId, stageId - 1, OPCODES['LRU_PURGE'], stageId, 1, stageId - 1))
    exec("p4_pd.execute_%d_table_add_with_skip(p4_pd.execute_%d_match_spec_t(ap_%d__opcode=%d, meta_disabled_start=0, meta_disabled_end=0, meta_mbr_start=0, meta_mbr_end=hex_to_i16(0xFFFF), meta_quota_start=%d, meta_quota_end=11, meta_complete=0, meta_lru_target_start=%d, meta_lru_target_end=%d), 1)" % (stageId, stageId, stageId - 1, OPCODES['LRU_PURGE'], stageId, stageId + 1, 15))
    """

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

p4_pd.check_completion_table_add_with_passthru(
    p4_pd.check_completion_match_spec_t(
        1
    )
)

print "execute table entries added"

for dst in ip_dsts:
    p4_pd.forward_table_add_with_setegr(
        p4_pd.forward_match_spec_t(
            0,
            0,
            0,
            ipv4Addr_to_i32(dst), 
            32
        ),
        p4_pd.setegr_action_spec_t(dpmap[ip_dsts[dst]])
    )
    p4_pd.forward_table_add_with_setegr(
        p4_pd.forward_match_spec_t(
            0,
            1,
            0,
            ipv4Addr_to_i32(dst), 
            32
        ),
        p4_pd.setegr_action_spec_t(dpmap[ip_dsts[dst]])
    )
    p4_pd.forward_table_add_with_setegr(
        p4_pd.forward_match_spec_t(
            1,
            0,
            0,
            ipv4Addr_to_i32(dst), 
            32
        ),
        p4_pd.setegr_action_spec_t(dpmap[ip_dsts[dst]])
    )
    p4_pd.backward_table_add_with_setrts(
        p4_pd.backward_match_spec_t(
            ipv4Addr_to_i32(dst)
        ),
        p4_pd.setrts_action_spec_t(mirror_ids[dst])
    )

p4_pd.forward_table_add_with_setegr(
    p4_pd.forward_match_spec_t(
        0,
        0,
        1,
        ipv4Addr_to_i32("0.0.0.0"),
        0
    ),
    p4_pd.setegr_action_spec_t(dpmap[8])
)

print "forward table entries added"

"""FREQTHRES = {
    1   : 10
}
for fid in FIDS:
    p4_pd.measure_freq_table_add_with_rmwfreq(
        p4_pd.measure_freq_match_spec_t(
            as_fid=fid,
            as_flag_resetfreq=0
        )
    )
    p4_pd.measure_freq_table_add_with_resetfreq(
        p4_pd.measure_freq_match_spec_t(
            as_fid=fid,
            as_flag_resetfreq=1
        )
    )
    if fid in FREQTHRES:
        for color in range(0, 3):
            p4_pd.filter_table_add_with_dofilter(
                p4_pd.filter_match_spec_t(
                    as_flag_resetfreq=0,
                    as_fid=fid,
                    as_freq_start=FREQTHRES[fid],
                    as_freq_end=hex_to_i16(0xFFFF),
                    meta_color=color
                ),
                1
            )
            p4_pd.filter_table_add_with_resetbloom(
                p4_pd.filter_match_spec_t(
                    as_flag_resetfreq=1,
                    as_fid=fid,
                    as_freq_start=0,
                    as_freq_end=hex_to_i16(0xFFFF),
                    meta_color=color
                ),
                1
            )"""

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

print "monitor entries added"

def addProgressTableEntry(action, flag_rts, flag_aux, skipped, complete, duplicate, mirrorPort):
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
        1,
        p4_pd.%s_action_spec_t(%d)
    )''' % (
        action, 
        flag_rts,
        flag_aux, 
        skipped, 
        complete, 
        duplicate, 
        action, 
        mirrorPort
    )
    exec(cmd)

addProgressTableEntry('cycle', 0, 0, 0, 0, 0, 5)
addProgressTableEntry('cycle_clone', 0, 0, 0, 0, 1, 5)
addProgressTableEntry('cycle', 1, 0, 0, 0, 0, 5)
addProgressTableEntry('cycle_clone', 1, 0, 0, 0, 1, 5)
addProgressTableEntry('cycle', 0, 1, 0, 0, 0, 5)
addProgressTableEntry('cycle_clone', 0, 1, 0, 0, 1, 5)
addProgressTableEntry('cycle_aux', 0, 0, 1, 0, 0, 5)
addProgressTableEntry('cycle_clone_aux', 0, 0, 1, 0, 1, 5)

p4_pd.progress_table_add_with_cycle_redirect(
    p4_pd.progress_match_spec_t(
        as_flag_rts=1,
        as_flag_aux=0,
        meta_skipped=0,
        meta_complete=1,
        meta_duplicate=0,
        meta_cycles_start=1,
        meta_cycles_end=hex_to_byte(0xFF)
    ),
    1
)

print "progress table entries added"

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
"""
p4_pd.checkgc_table_add_with_initiate_gc(
    p4_pd.checkgc_match_spec_t(
        as_flag=6
    )
)"""

# TRAFFIC MONITORING

CIR_KBPS = 1
CBS_KBITS = 5
PIR_CBPS = 5
PBS_KBITS = 5
GREEN = 0
YELLOW = 1
RED = 2

"""for fid in FIDS:
    p4_pd.resources_table_add_with_set_quota(
        p4_pd.resources_match_spec_t(
            as_fid=fid
        ),
        p4_pd.set_quota_action_spec_t(
            QUOTAS[fid][0], 
            QUOTAS[fid][1], 
            hex_to_i16(VERTICAL_QUOTAS[fid][0]),
            5
        ),
        p4_pd.bytes_meter_spec_t(CIR_KBPS, CBS_KBITS, PIR_CBPS, PBS_KBITS, False)
    )"""

"""p4_pd.monitor_table_add_with_report(
    p4_pd.monitor_match_spec_t(
        meta_color=GREEN
    )
)
p4_pd.monitor_table_add_with_report(
    p4_pd.monitor_match_spec_t(
        meta_color=YELLOW
    )
)
p4_pd.monitor_table_add_with_report(
    p4_pd.monitor_match_spec_t(
        meta_color=RED
    )
)"""

p4_pd.resources_set_default_action_passthru(
    p4_pd.bytes_meter_spec_t(CIR_KBPS, CBS_KBITS, PIR_CBPS, PBS_KBITS, False)
)
p4_pd.cycleupdate_set_default_action_update_cycles()

p4_pd.check_alloc_status_table_add_with_dofilter_alloc(
    p4_pd.check_alloc_status_match_spec_t(
        as_flag_reqalloc=1
    )
)

p4_pd.memalloc_table_add_with_request_allocation(
    p4_pd.memalloc_match_spec_t(
        as_flag_reqalloc=1,
        meta_alloc_init=1
    )
)

p4_pd.execute_3_table_add_with_memory_3_read(
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
        as_fid=10
    ),
    1
)

p4_pd.execute_3_table_add_with_memory_3_write(
    p4_pd.execute_3_match_spec_t(
        ap_2__opcode=5, 
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
        as_fid=10
    ),
    1
)

conn_mgr.complete_operations()

print "TABLE CONFIGURATION COMPLETE!"