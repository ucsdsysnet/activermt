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

register heap_9 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_9 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_9_read {
    reg                 : heap_9;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_9_read() {
    heap_9_read.execute_stateful_alu(meta.mar);
    //count(hit_9, meta.mar);
}

/*blackbox stateful_alu heap_9_write {
    reg                     : heap_9;
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

blackbox stateful_alu heap_9_write {
    
    reg                     : heap_9;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_9_write() {
    heap_9_write.execute_stateful_alu(meta.mar);
    //count(hit_9, meta.mar);
}

/*blackbox stateful_alu heap_9_reset {
    reg                     : heap_9;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_9_reset() {
    heap_9_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_9_rmw {
    reg                     : heap_9;
    
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

action counter_9_rmw() {
    count_9_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_9_sub {
    reg                     : heap_9;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_9_sub() {
    heap_9_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_9 {
    reads {
        ap[8].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_9_rmw;
        memory_9_read;
        memory_9_write;
        memory_9_sub;
    }
}*/

register prog_9 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_9_write {
    
    reg                     : prog_9;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[8].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[8].goto;
}

action write_prog_9() {
    prog_9_write.execute_stateful_alu(as.fid);
}

register heap_10 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_10 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_10_read {
    reg                 : heap_10;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_10_read() {
    heap_10_read.execute_stateful_alu(meta.mar);
    //count(hit_10, meta.mar);
}

/*blackbox stateful_alu heap_10_write {
    reg                     : heap_10;
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

blackbox stateful_alu heap_10_write {
    
    reg                     : heap_10;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_10_write() {
    heap_10_write.execute_stateful_alu(meta.mar);
    //count(hit_10, meta.mar);
}

/*blackbox stateful_alu heap_10_reset {
    reg                     : heap_10;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_10_reset() {
    heap_10_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_10_rmw {
    reg                     : heap_10;
    
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

action counter_10_rmw() {
    count_10_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_10_sub {
    reg                     : heap_10;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_10_sub() {
    heap_10_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_10 {
    reads {
        ap[9].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_10_rmw;
        memory_10_read;
        memory_10_write;
        memory_10_sub;
    }
}*/

register prog_10 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_10_write {
    
    reg                     : prog_10;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[9].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[9].goto;
}

action write_prog_10() {
    prog_10_write.execute_stateful_alu(as.fid);
}

register heap_11 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_11 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_11_read {
    reg                 : heap_11;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_11_read() {
    heap_11_read.execute_stateful_alu(meta.mar);
    //count(hit_11, meta.mar);
}

/*blackbox stateful_alu heap_11_write {
    reg                     : heap_11;
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

blackbox stateful_alu heap_11_write {
    
    reg                     : heap_11;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_11_write() {
    heap_11_write.execute_stateful_alu(meta.mar);
    //count(hit_11, meta.mar);
}

/*blackbox stateful_alu heap_11_reset {
    reg                     : heap_11;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_11_reset() {
    heap_11_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_11_rmw {
    reg                     : heap_11;
    
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

action counter_11_rmw() {
    count_11_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_11_sub {
    reg                     : heap_11;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_11_sub() {
    heap_11_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_11 {
    reads {
        ap[10].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_11_rmw;
        memory_11_read;
        memory_11_write;
        memory_11_sub;
    }
}*/

register prog_11 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_11_write {
    
    reg                     : prog_11;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[10].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[10].goto;
}

action write_prog_11() {
    prog_11_write.execute_stateful_alu(as.fid);
}

register heap_12 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_12 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_12_read {
    reg                 : heap_12;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_12_read() {
    heap_12_read.execute_stateful_alu(meta.mar);
    //count(hit_12, meta.mar);
}

/*blackbox stateful_alu heap_12_write {
    reg                     : heap_12;
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

blackbox stateful_alu heap_12_write {
    
    reg                     : heap_12;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_12_write() {
    heap_12_write.execute_stateful_alu(meta.mar);
    //count(hit_12, meta.mar);
}

/*blackbox stateful_alu heap_12_reset {
    reg                     : heap_12;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_12_reset() {
    heap_12_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_12_rmw {
    reg                     : heap_12;
    
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

action counter_12_rmw() {
    count_12_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_12_sub {
    reg                     : heap_12;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_12_sub() {
    heap_12_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_12 {
    reads {
        ap[11].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_12_rmw;
        memory_12_read;
        memory_12_write;
        memory_12_sub;
    }
}*/

register prog_12 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_12_write {
    
    reg                     : prog_12;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[11].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[11].goto;
}

action write_prog_12() {
    prog_12_write.execute_stateful_alu(as.fid);
}

register heap_13 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_13 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_13_read {
    reg                 : heap_13;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_13_read() {
    heap_13_read.execute_stateful_alu(meta.mar);
    //count(hit_13, meta.mar);
}

/*blackbox stateful_alu heap_13_write {
    reg                     : heap_13;
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

blackbox stateful_alu heap_13_write {
    
    reg                     : heap_13;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_13_write() {
    heap_13_write.execute_stateful_alu(meta.mar);
    //count(hit_13, meta.mar);
}

/*blackbox stateful_alu heap_13_reset {
    reg                     : heap_13;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_13_reset() {
    heap_13_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_13_rmw {
    reg                     : heap_13;
    
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

action counter_13_rmw() {
    count_13_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_13_sub {
    reg                     : heap_13;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_13_sub() {
    heap_13_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_13 {
    reads {
        ap[12].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_13_rmw;
        memory_13_read;
        memory_13_write;
        memory_13_sub;
    }
}*/

register prog_13 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_13_write {
    
    reg                     : prog_13;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[12].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[12].goto;
}

action write_prog_13() {
    prog_13_write.execute_stateful_alu(as.fid);
}

register heap_14 {
    width           : 32;
    instance_count  : 65536;
}

/*counter hit_14 {
    type            : packets;
    instance_count  : 65536;
}*/

blackbox stateful_alu heap_14_read {
    reg                 : heap_14;
    condition_lo        : register_lo == meta.mar;
    condition_hi        : meta.mbr > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.mbr;
    output_value        : register_hi;
}

action memory_14_read() {
    heap_14_read.execute_stateful_alu(meta.mar);
    //count(hit_14, meta.mar);
}

/*blackbox stateful_alu heap_14_write {
    reg                     : heap_14;
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

blackbox stateful_alu heap_14_write {
    
    reg                     : heap_14;

    update_lo_1_predicate   : true;
    update_lo_1_value       : meta.mar;

    update_hi_1_predicate   : true;
    update_hi_1_value       : meta.mbr;
}

action memory_14_write() {
    heap_14_write.execute_stateful_alu(meta.mar);
    //count(hit_14, meta.mar);
}

/*blackbox stateful_alu heap_14_reset {
    reg                     : heap_14;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_14_reset() {
    heap_14_reset.execute_stateful_alu(meta.mar);
}*/

blackbox stateful_alu count_14_rmw {
    reg                     : heap_14;
    
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

action counter_14_rmw() {
    count_14_rmw.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu heap_14_sub {
    reg                     : heap_14;

    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;

    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi - meta.mbr;

    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : alu_hi;
}

action memory_14_sub() {
    heap_14_sub.execute_stateful_alu(meta.mar);
}

/*table memaccess_14 {
    reads {
        ap[13].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
        counter_14_rmw;
        memory_14_read;
        memory_14_write;
        memory_14_sub;
    }
}*/

register prog_14 {
    width           : 16;
    instance_count  : 256;
}

blackbox stateful_alu prog_14_write {
    
    reg                     : prog_14;

    update_lo_1_predicate   : true;
    update_lo_1_value       : ap[13].opcode;

    update_hi_1_predicate   : true;
    update_hi_1_value       : ap[13].goto;
}

action write_prog_14() {
    prog_14_write.execute_stateful_alu(as.fid);
}