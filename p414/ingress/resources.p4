action seed() {
    modify_field_rng_uniform(as.freq, 0, 65535);
}

table preplimit {
    reads {
        as.fid      : exact;
    }
    actions {
        seed;
    }
}

action set_quota(quota_start, quota_end, cycles) {
    modify_field(meta.quota_start, quota_start);
    modify_field(meta.quota_end, quota_end);
    modify_field(meta.cycles, cycles);
    modify_field(as.acc, cycles);
}

table resources {
    reads {
        as.fid      : exact;
        as.freq     : range;
    }
    actions {
        set_quota;
        passthru;
    }
} 