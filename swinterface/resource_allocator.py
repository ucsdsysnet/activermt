import json
from time import time

NUM_STEPS       = 1
APPS_PER_STAGE  = 1
BLOCK_SIZE      = 8192

MBR_MIN         = 0
MBR_MAX         = 0xFFFF
ENABLED         = 0
DISABLED_SOFT   = 1
DISABLED_HARD   = 2

OPCODES = json.loads(open('./opcodes.json').read(), encoding='utf-8')

FIDS = {}
QUOTAS = {}
VERTICAL_QUOTAS = {}
for stage in range(0, NUM_STEPS):
    for id in range(0, APPS_PER_STAGE):
        fid  = id + 1
        FIDS[fid] = 'function_%d' % fid
        QUOTAS[fid] = (stage + 1, stage + 1)
        VERTICAL_QUOTAS[fid] = (id * BLOCK_SIZE, fid * BLOCK_SIZE - 1)

OPS_MEMACCESS = [
    "MEM_READ",
    "MEM_WRITE",
    "MEM_RST"
]
ACTIONS = {
    'MEM_READ'          : "memory_%d_read",
    'MEM_WRITE'         : "memory_%d_write",
    'MEM_RST'           : "memory_%d_reset"
}

def addExecuteTableEntry(stageId, action, opcode, isDisabled, mbrStart, mbrEnd, port=-1):
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
        memStart = VERTICAL_QUOTAS[fid][0]
        memEnd = VERTICAL_QUOTAS[fid][1]
        if memStart > 0:
            lStart = 'hex_to_i16(0x0)'
            lEnd = 'hex_to_i16(0x%x)' % (memStart - 1)
            exec(cmd % (
                    stageId, 'memfault', stageId, 
                    stageId - 1, opcode, 
                    disabledStart, disabledEnd, 
                    mbrStart, mbrEnd, 
                    max(stageId + 1, 12), 12, 0, min(stageId - 1, 0),
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
                    max(stageId + 1, 12), 12, 0, min(stageId - 1, 0),
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
        )

measurements = []
NUM_ITER = 1000
for i in range(0, NUM_ITER):
    start = time()
    clear_all()
    for op in OPS_MEMACCESS:
        for stage in range(0, NUM_STEPS):
            addExecuteTableEntry(stage + 1, ACTIONS[op] % (stage + 1), OPCODES[op], DISABLED_HARD, MBR_MIN, MBR_MAX)
    stop = time()
    elapsed = stop - start
    measurements.append(str(elapsed))
    conn_mgr.complete_operations()

with open('measurements_memtables_single.csv', 'w') as out:
    out.write("\n".join(measurements))
    out.close()

print "DONE!"