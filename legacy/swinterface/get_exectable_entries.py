NUM_STAGES = 17

entries = {}

for i in range(0, NUM_STAGES):
    stageId = i + 1
    opId = i if stageId < 7 else i - 6
    spec = getattr(p4_pd, "execute_%d_get_entry_count" % stageId)
    num_entries = spec()
    spec = getattr(p4_pd, "execute_%d_get_first_entry_handle" % stageId)
    hdl = spec()
    for j in range(0, num_entries - 1):
        spec = getattr(p4_pd, "execute_%d_get_entry" % stageId)
        entry = spec(hdl, from_hw)
        if entry.match_spec.as_fid not in entries:
            entries[entry.match_spec.as_fid] = {}
        if stageId not in entries[entry.match_spec.as_fid]:
            entries[entry.match_spec.as_fid][stageId] = []
        entries[entry.match_spec.as_fid][stageId].append([
            entry.match_spec.as_fid,
            stageId,
            entry.match_spec.meta_mbr_start,
            entry.match_spec.meta_mbr_end,
            entry.match_spec.meta_mar_start,
            entry.match_spec.meta_mar_end,
            entry.match_spec.meta_disabled,
            entry.match_spec.meta_complete,
            getattr(entry.match_spec, 'ap_%d__opcode' % opId)
        ])
        #spec = getattr(p4_pd, "execute_%d_get_next_entry_handles" % stageId)
        #hdl = spec(hdl, from_hw)
        hdl = hdl + 1

data = []
for fid in entries:
    print("entries exist for FID %d" % fid)
    for e in entries[fid]:
        for s in entries[fid][e]:
            data.append(",".join([ str(x) for x in s ]))

with open("execute_entries.csv", "w") as out:
    out.write("\n".join(data))
    out.close()