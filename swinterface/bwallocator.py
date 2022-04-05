fid = 10
maxCycles = 5
pct = 0.5

cir = 5
cbs = 5
pir = 1
pbs = 5

#p4_pd.resources_table_delete(2)
#p4_pd.resources_table_delete(3)

p4_pd.resources_table_add_with_set_quota(
    p4_pd.resources_match_spec_t(
        as_fid=fid,
        as_freq_start=0,
        as_freq_end=hex_to_i16(0xFFFF * pct)
    ),
    p4_pd.set_quota_action_spec_t(
        1, 
        11, 
        0,
        maxCycles
    ),
    1,
    p4_pd.bytes_meter_spec_t(cir, cbs, pir, pbs, False)
)

p4_pd.resources_table_add_with_set_quota(
    p4_pd.resources_match_spec_t(
        as_fid=fid,
        as_freq_start=hex_to_i16(0xFFFF * pct + 1),
        as_freq_end=hex_to_i16(0xFFFF)
    ),
    p4_pd.set_quota_action_spec_t(
        1, 
        11, 
        0,
        1
    ),
    1,
    p4_pd.bytes_meter_spec_t(cir, cbs, pir, pbs, False)
)

conn_mgr.complete_operations()