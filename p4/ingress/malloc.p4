register bloom_alloc {
    width           : 8;
    instance_count  : 65536;
}

blackbox stateful_alu bloom_alloc_filter {
    reg                     : bloom_alloc;
    condition_lo            : register_lo == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 1;
    output_predicate        : condition_lo;
    output_dst              : meta.alloc_init;
    output_value            : 1;
}

action dofilter_alloc() {
    bloom_alloc_filter.execute_stateful_alu(as.fid);
}

table check_alloc_status {
    reads {
        as.flag_reqalloc    : exact;
    }
    actions {
        dofilter_alloc;
    }
}

field_list alloc_params {
    as.fid;
    as.acc;
}

action request_allocation() {
    generate_digest(0, alloc_params);
    modify_field(as.flag_allocated, 0);
    return_to_sender();
    bypass_egress();
}

table memalloc {
    reads {
        as.flag_reqalloc    : exact;
        meta.alloc_init     : exact;
    }
    actions {
        request_allocation;
    }
}

action return_allocation(alloc_id, memstart, memend) {
    modify_field(as.id, alloc_id);
    modify_field(as.acc, memstart);
    modify_field(as.acc2, memend);
    modify_field(as.flag_allocated, 1);
    return_to_sender();
    bypass_egress();
}

table getalloc {
    reads {
        as.fid              : exact;
        as.flag_reqalloc    : exact;
    }
    actions {
        return_allocation;
    }
}