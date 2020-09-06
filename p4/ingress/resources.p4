action set_quota(quota_start, quota_end, cycles) {
    modify_field(meta.quota_start, quota_start);
    modify_field(meta.quota_end, quota_end);
    modify_field(meta.cycles, cycles);
}

table resources {
    reads {
        as.fid      : exact;
    }
    actions {
        set_quota;
        passthru;
    }
}