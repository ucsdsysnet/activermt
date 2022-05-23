from time import time

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

conn_mgr.complete_operations()