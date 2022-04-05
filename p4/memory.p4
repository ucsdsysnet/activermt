register heap_1 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_1 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_1_read {
    reg                 : heap_1;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_1_read() {
    heap_1_read.execute_stateful_alu(meta.mar);
    //count(hit_1, meta.mar);
}

/*blackbox stateful_alu heap_1_write {
    reg                     : heap_1;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_1_write {
    
    reg                     : heap_1;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_1_write() {
    heap_1_write.execute_stateful_alu(meta.mar);
    //count(hit_1, meta.mar);
}

/*blackbox stateful_alu heap_1_reset {
    reg                     : heap_1;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_1_reset() {
    heap_1_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_1_rmw {
    reg                     : heap_1;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_1_rmw() {
    count_1_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_1_sub {
    reg                     : heap_1;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_1_sub() {
    heap_1_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_1 {
    reads {
        ap[0].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_1_rmw;
        memory_1_read;
        memory_1_write;
        memory_1_sub;
    }
}*/

register prog_1 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_1_write {
    
    reg                     : prog_1;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[0].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[0].goto;
}

action write_prog_1() {
    prog_1_write.execute_stateful_alu(as.fid);
}

register heap_2 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_2 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_2_read {
    reg                 : heap_2;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_2_read() {
    heap_2_read.execute_stateful_alu(meta.mar);
    //count(hit_2, meta.mar);
}

/*blackbox stateful_alu heap_2_write {
    reg                     : heap_2;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_2_write {
    
    reg                     : heap_2;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_2_write() {
    heap_2_write.execute_stateful_alu(meta.mar);
    //count(hit_2, meta.mar);
}

/*blackbox stateful_alu heap_2_reset {
    reg                     : heap_2;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_2_reset() {
    heap_2_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_2_rmw {
    reg                     : heap_2;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_2_rmw() {
    count_2_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_2_sub {
    reg                     : heap_2;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_2_sub() {
    heap_2_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_2 {
    reads {
        ap[1].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_2_rmw;
        memory_2_read;
        memory_2_write;
        memory_2_sub;
    }
}*/

register prog_2 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_2_write {
    
    reg                     : prog_2;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[1].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[1].goto;
}

action write_prog_2() {
    prog_2_write.execute_stateful_alu(as.fid);
}

register heap_3 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_3 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_3_read {
    reg                 : heap_3;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_3_read() {
    heap_3_read.execute_stateful_alu(meta.mar);
    //count(hit_3, meta.mar);
}

/*blackbox stateful_alu heap_3_write {
    reg                     : heap_3;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_3_write {
    
    reg                     : heap_3;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_3_write() {
    heap_3_write.execute_stateful_alu(meta.mar);
    //count(hit_3, meta.mar);
}

/*blackbox stateful_alu heap_3_reset {
    reg                     : heap_3;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_3_reset() {
    heap_3_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_3_rmw {
    reg                     : heap_3;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_3_rmw() {
    count_3_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_3_sub {
    reg                     : heap_3;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_3_sub() {
    heap_3_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_3 {
    reads {
        ap[2].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_3_rmw;
        memory_3_read;
        memory_3_write;
        memory_3_sub;
    }
}*/

register prog_3 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_3_write {
    
    reg                     : prog_3;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[2].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[2].goto;
}

action write_prog_3() {
    prog_3_write.execute_stateful_alu(as.fid);
}

register heap_4 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_4 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_4_read {
    reg                 : heap_4;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_4_read() {
    heap_4_read.execute_stateful_alu(meta.mar);
    //count(hit_4, meta.mar);
}

/*blackbox stateful_alu heap_4_write {
    reg                     : heap_4;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_4_write {
    
    reg                     : heap_4;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_4_write() {
    heap_4_write.execute_stateful_alu(meta.mar);
    //count(hit_4, meta.mar);
}

/*blackbox stateful_alu heap_4_reset {
    reg                     : heap_4;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_4_reset() {
    heap_4_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_4_rmw {
    reg                     : heap_4;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_4_rmw() {
    count_4_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_4_sub {
    reg                     : heap_4;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_4_sub() {
    heap_4_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_4 {
    reads {
        ap[3].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_4_rmw;
        memory_4_read;
        memory_4_write;
        memory_4_sub;
    }
}*/

register prog_4 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_4_write {
    
    reg                     : prog_4;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[3].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[3].goto;
}

action write_prog_4() {
    prog_4_write.execute_stateful_alu(as.fid);
}

register heap_5 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_5 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_5_read {
    reg                 : heap_5;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_5_read() {
    heap_5_read.execute_stateful_alu(meta.mar);
    //count(hit_5, meta.mar);
}

/*blackbox stateful_alu heap_5_write {
    reg                     : heap_5;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_5_write {
    
    reg                     : heap_5;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_5_write() {
    heap_5_write.execute_stateful_alu(meta.mar);
    //count(hit_5, meta.mar);
}

/*blackbox stateful_alu heap_5_reset {
    reg                     : heap_5;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_5_reset() {
    heap_5_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_5_rmw {
    reg                     : heap_5;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_5_rmw() {
    count_5_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_5_sub {
    reg                     : heap_5;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_5_sub() {
    heap_5_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_5 {
    reads {
        ap[4].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_5_rmw;
        memory_5_read;
        memory_5_write;
        memory_5_sub;
    }
}*/

register prog_5 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_5_write {
    
    reg                     : prog_5;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[4].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[4].goto;
}

action write_prog_5() {
    prog_5_write.execute_stateful_alu(as.fid);
}

register heap_6 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_6 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_6_read {
    reg                 : heap_6;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_6_read() {
    heap_6_read.execute_stateful_alu(meta.mar);
    //count(hit_6, meta.mar);
}

/*blackbox stateful_alu heap_6_write {
    reg                     : heap_6;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_6_write {
    
    reg                     : heap_6;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_6_write() {
    heap_6_write.execute_stateful_alu(meta.mar);
    //count(hit_6, meta.mar);
}

/*blackbox stateful_alu heap_6_reset {
    reg                     : heap_6;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_6_reset() {
    heap_6_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_6_rmw {
    reg                     : heap_6;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_6_rmw() {
    count_6_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_6_sub {
    reg                     : heap_6;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_6_sub() {
    heap_6_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_6 {
    reads {
        ap[5].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_6_rmw;
        memory_6_read;
        memory_6_write;
        memory_6_sub;
    }
}*/

register prog_6 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_6_write {
    
    reg                     : prog_6;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[5].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[5].goto;
}

action write_prog_6() {
    prog_6_write.execute_stateful_alu(as.fid);
}

register heap_7 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_7 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_7_read {
    reg                 : heap_7;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_7_read() {
    heap_7_read.execute_stateful_alu(meta.mar);
    //count(hit_7, meta.mar);
}

/*blackbox stateful_alu heap_7_write {
    reg                     : heap_7;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_7_write {
    
    reg                     : heap_7;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_7_write() {
    heap_7_write.execute_stateful_alu(meta.mar);
    //count(hit_7, meta.mar);
}

/*blackbox stateful_alu heap_7_reset {
    reg                     : heap_7;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_7_reset() {
    heap_7_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_7_rmw {
    reg                     : heap_7;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_7_rmw() {
    count_7_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_7_sub {
    reg                     : heap_7;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_7_sub() {
    heap_7_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_7 {
    reads {
        ap[6].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_7_rmw;
        memory_7_read;
        memory_7_write;
        memory_7_sub;
    }
}*/

register prog_7 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_7_write {
    
    reg                     : prog_7;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[6].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[6].goto;
}

action write_prog_7() {
    prog_7_write.execute_stateful_alu(as.fid);
}

register heap_8 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_8 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_8_read {
    reg                 : heap_8;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_8_read() {
    heap_8_read.execute_stateful_alu(meta.mar);
    //count(hit_8, meta.mar);
}

/*blackbox stateful_alu heap_8_write {
    reg                     : heap_8;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 0;
    output_dst              : meta.disabled;
}*/

blackbox stateful_alu heap_8_write {
    
    reg                     : heap_8;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_8_write() {
    heap_8_write.execute_stateful_alu(meta.mar);
    //count(hit_8, meta.mar);
}

/*blackbox stateful_alu heap_8_reset {
    reg                     : heap_8;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_8_reset() {
    heap_8_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_8_rmw {
    reg                     : heap_8;
    
    //condition_hi            : meta.mbr == 0;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi + 1;
    /*update_hi_2_predicate   : condition_hi;
    update_hi_2_value       : register_hi - 1;*/

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action counter_8_rmw() {
    count_8_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_8_sub {
    reg                     : heap_8;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_8_sub() {
    heap_8_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_8 {
    reads {
        ap[7].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_8_rmw;
        memory_8_read;
        memory_8_write;
        memory_8_sub;
    }
}*/

register prog_8 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_8_write {
    
    reg                     : prog_8;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[7].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[7].goto;
}

action write_prog_8() {
    prog_8_write.execute_stateful_alu(as.fid);
}