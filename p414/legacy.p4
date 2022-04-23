field_list freq_access_list {
    as.fid;
}

field_list_calculation freq_index {
    input           { freq_access_list; }
    algorithm       : identity;
    output_width    : 16;
}

register frequency {
    width           : 16;
    instance_count  : 65536;
}

blackbox stateful_alu frequency_rmw {
    reg                     : frequency;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    output_predicate        : true;
    output_dst              : as.freq;
    output_value            : register_lo;
}

blackbox stateful_alu frequency_reset {
    reg                     : frequency;
    update_lo_1_predicate   : true;
    update_lo_1_value       : 0;
}

action rmwfreq() {
    frequency_rmw.execute_stateful_alu_from_hash(freq_index);
}

action resetfreq() {
    frequency_reset.execute_stateful_alu_from_hash(freq_index);
}

table measure_freq {
    reads {
        as.fid              : exact;
        as.flag_resetfreq   : exact;
    }
    actions {
        rmwfreq;
        resetfreq;
    }
}

register bloom {
    width           : 8;
    instance_count  : 65536;
}

blackbox stateful_alu bloom_filter {
    reg                     : bloom;
    condition_lo            : register_lo == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 1;
    output_predicate        : condition_lo;
    output_dst              : meta.digest;
    output_value            : 1;
}

blackbox stateful_alu bloom_reset {
    reg                     : bloom;
    update_lo_1_predicate   : true;
    update_lo_1_value       : 0;
}

action dofilter() {
    bloom_filter.execute_stateful_alu_from_hash(freq_index);
}

action resetbloom() {
    bloom_reset.execute_stateful_alu_from_hash(freq_index);
}

table filter {
    reads {
        as.flag_resetfreq   : exact;
        as.fid              : exact;
        as.freq             : range;
        meta.color          : exact;
    }
    actions {
        dofilter;
        resetbloom;
    }
}

field_list gc_params {
    as.id;
    as.acc;
    as.acc2;
}

action initiate_gc() {
    generate_digest(0, gc_params);
    drop();
    passthru();
}

table checkgc {
    reads {
        as.flag : exact;
    }
    actions {
        initiate_gc;
    }
}