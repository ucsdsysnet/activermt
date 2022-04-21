from time import time

OPCODES = {}
opcodeList = open('../config/opcodes.csv').read().strip().splitlines()
for id in range(0, len(opcodeList)):
    OPCODES[ opcodeList[id] ] = id + 1

OPS_MEMACCESS = [
    "MEM_READ",
    "MEM_WRITE",
    "COUNTER_RMW"
]
OPCODES_MEMACCESS = []
for op in OPS_MEMACCESS:
    OPCODES_MEMACCESS.append(OPCODES[op])

MAX_HANDLES = 1000
OP_MEMREAD = "MEM_READ"

mappings = {}

head = p4_pd.execute_1_get_first_entry_handle()
hdls = p4_pd.execute_1_get_next_entry_handles(head, MAX_HANDLES)

print "<MEMORY ALLOCATION>"
print ""
for hdl in hdls:
    if hdl <= 0:
        continue
    entry = p4_pd.execute_1_get_entry(hdl, 0)
    action = str(entry.action_desc.name)
    #and action != "memfault"
    if entry.match_spec.ap_0__opcode in OPCODES_MEMACCESS and entry.match_spec.as_fid < 3:
        print "FID %d :: [%x - %x] %s" % (entry.match_spec.as_fid, i16_to_hex(entry.match_spec.meta_mar_start), i16_to_hex(entry.match_spec.meta_mar_end), action)
        if entry.match_spec.as_fid not in mappings:
            mappings[entry.match_spec.as_fid] = { 
                'start': i16_to_hex(entry.match_spec.meta_mar_start), 
                'end': i16_to_hex(entry.match_spec.meta_mar_end), 
                'actions': [] 
            }
        mappings[entry.match_spec.as_fid]['actions'].append(action)

"""for fid in mappings:
    print "FID %d : [ %d, %u ] -> %s" % (fid, mappings[fid]['start'], mappings[fid]['end'], ", ".join(mappings[fid]['actions']))"""
print ""

conn_mgr.complete_operations()