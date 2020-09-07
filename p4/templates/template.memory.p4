register heap_# {
    width           : 32;
    instance_count  : 65536;
}

counter hit_# {
    type            : packets;
    instance_count  : 65536;
}

blackbox stateful_alu heap_#_read {
    reg                 : heap_#;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_#_read() {
    heap_#_read.execute_stateful_alu(meta.mar);
    //count(hit_#, meta.mar);
}

blackbox stateful_alu heap_#_write {
    reg                     : heap_#;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}

action memory_#_write() {
    heap_#_write.execute_stateful_alu(meta.mar);
    //count(hit_#, meta.mar);
}

blackbox stateful_alu heap_#_reset {
    reg                     : heap_#;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_#_reset() {
    heap_#_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_#_rmw {
    reg                     : heap_#;
    
    condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : not condition_hi;
    update_hi_1_value       : register_hi + 1;
    update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_#_rmw() {
    count_#_rmw.execute_stateful_alu(meta.mar);
}