#ifdef __TARGET_TOFINO__
#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>
#include <tofino/primitives.p4>
#include <tofino/stateful_alu_blackbox.p4>
#else
#error This program is intended to compile for Tofino P4 architecture only
#endif

#include "headers.p4"

#define FLAG_NONE       0
#define FLAG_REDIRECT   1
#define FLAG_IGCLONE    2
#define FLAG_BYPASS     3
#define FLAG_RTS        5
#define FLAG_GC         6
#define FLAG_AUX        8
#define FLAG_ACK        255

header_type pktgen_ts_t {
    fields {
        padding         : 48;
        timestamp       : 64;
        magic           : 16;
    }
}

header_type active_state_t {
    fields {
        flag_redirect   : 1;
        flag_igclone    : 1;
        flag_bypasseg   : 1;
        flag_rts        : 1;
        flag_gc         : 1;
        flag_aux        : 1;
        flag_ack        : 1;
        flag_done       : 1;
        flag_mfault     : 1;
        flag_resetfreq  : 1;
        flag_reqalloc   : 1;
        flag_allocated  : 1;
        padding         : 4;
        fid             : 16;
        acc             : 16;
        acc2            : 16;
        id              : 16;
        freq            : 16;
    }
}

header_type active_program_t {
    fields {
        flags   : 8;
        opcode  : 8;
        arg     : 16;
        goto    : 8;
    }
}

header ethernet_t           ethernet;
header ipv4_t               ipv4;
header udp_t                udp;
header pktgen_ts_t          ts;
header active_state_t       as;
header active_program_t     ap[11];

header_type metadata_t {
    fields {
        pc          : 8;
        quota_start : 8;
        quota_end   : 8; 
        loop        : 8;
        duplicate   : 1;
        mar         : 16;
        base        : 16;
        mbr         : 16;
        mbr2        : 16;
        mar_base    : 16;
        disabled    : 8;
        mirror_type : 1;
        mirror_sess : 10;
        complete    : 1;
        rtsid       : 16;
        lru_target  : 4;
        skipped     : 1;
        burnt_ipv4  : 16;
        burnt_udp   : 16;
        rts         : 1;
        color       : 4;
        digest      : 1;
        reset       : 1;
        alloc_init  : 1;
        cycles      : 8;
    }
}

metadata metadata_t meta;

////////////////// [PARSING] //////////////////

parser start {
    extract(ethernet);
    return select(ethernet.etherType) {
        0x0800 : parse_ipv4;
        default: ingress;
    }
}

parser parse_ipv4 {
    extract(ipv4);
    return select(ipv4.protocol) {
        0x11    : parse_udp;
        default : ingress;
    }
}

parser parse_udp {
    extract(udp);
    return select(udp.dstPort) {
        9876    : parse_active_state;
        9877    : parse_pktgen_ts;
        default : ingress;
    }
}

parser parse_pktgen_ts {
    extract(ts);
    return parse_active_state;
}

parser parse_active_state {
    extract(as);
    return select(as.flag_done) {
        0x01    : ingress;
        default : init_program;
    }
}

parser init_program {
    return select(as.flag_aux) {
        0x01        : skip_block;
        default     : continue_parsing;
    }
}

@pragma force_shift ingress 192
@pragma force_shift egress 192
parser skip_block {
    return attempt_resume;
}

parser attempt_resume {
    return select(current(0, 8)) {
        0x03    : continue_parsing;
        default : skip_block;
    }
}

parser continue_parsing {
    return select(current(0, 8)) {
        0x01    : skip_instruction;
        default : parse_active_program;
    }
}

@pragma force_shift ingress 48
@pragma force_shift egress 48
parser skip_instruction {
    return continue_parsing;
}

parser parse_active_program {
    extract(ap[next]);
    return select(latest.opcode) {
        0x08    : ingress;
        default : parse_active_program;
    }
}

field_list ipv4_checksum_list {
    ipv4.version;
    ipv4.ihl;
    ipv4.diffserv;
    ipv4.totalLen;
    ipv4.identification;
    ipv4.flags;
    ipv4.fragOffset;
    ipv4.ttl;
    ipv4.protocol;
    ipv4.srcAddr;
    ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input        { ipv4_checksum_list; }
    algorithm    : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum;
    update ipv4_checksum;
}

////////////////// [INGRESS] //////////////////

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

/*field_list freq_access_list {
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
}*/

// report

register bloom_meter {
    width           : 8;
    instance_count  : 65536;
}

blackbox stateful_alu bloom_meter_filter {
    reg                     : bloom_meter;
    condition_lo            : register_lo == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 1;
    output_predicate        : condition_lo;
    output_dst              : meta.digest;
    output_value            : 1;
}

action dofilter_meter() {
    bloom_meter_filter.execute_stateful_alu(as.fid);
}

table filter_meter {
    reads {
        meta.color          : exact;
    }
    actions {
        dofilter_meter;
    }
}

meter function_meter {
    type            : bytes;
    direct          : resources;
    result          : meta.color;
}

field_list meter_params {
    as.fid;
    meta.color;
}

action report() {
    generate_digest(0, meter_params);
}

table monitor {
    reads {
        meta.digest : exact;
    }
    actions {
        report;
    }
}

action setegr(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
    modify_field(as.flag_aux, 0);
}

action setrts(mirror_id) {
    modify_field(meta.rtsid, mirror_id);
}

table forward {
    reads {
        as.flag_aux         : exact;
        as.flag_ack         : exact;
        as.flag_redirect    : exact;
        ipv4.dstAddr        : lpm;
    }
    actions {
        setegr;
    }
}

table backward {
    reads {
        ipv4.srcAddr    : exact;
    }
    actions {
        setrts;
    }
}

action set_quota(quota_start, quota_end, addr_base, cycles) {
    modify_field(meta.quota_start, quota_start);
    modify_field(meta.quota_end, quota_end);
    modify_field(meta.base, addr_base);
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

action passthru() {
    bypass_egress();
}

table check_completion {
    reads {
        as.flag_done : exact;
    }
    actions {
        passthru;
    }
}
/*
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
*/
control ingress {
    /*apply(checkgc) {
        miss {
            apply(resources);
            apply(forward);
            apply(backward);
            apply(check_completion);
        }
    }*/
    apply(check_alloc_status);
    apply(memalloc) {
        miss {
            apply(getalloc);
        }
    }
    /*apply(measure_freq);
    apply(filter);*/
    apply(resources);
    apply(filter_meter);
    apply(monitor);
    apply(forward);
    apply(backward);
    apply(check_completion);
}

/////////////////// [EGRESS] //////////////////

register heap_1 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_1 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_1_write {
    reg                     : heap_1;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_1_write() {
    heap_1_write.execute_stateful_alu(meta.mar);
    //count(hit_1, meta.mar);
}

blackbox stateful_alu heap_1_reset {
    reg                     : heap_1;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_1_reset() {
    heap_1_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_1_rmw {
    reg                     : heap_1;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_1_rmw() {
    count_1_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_1 {
    reg                     : heap_1;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_1() {
    count_minread_1.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_2 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_2 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_2_write {
    reg                     : heap_2;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_2_write() {
    heap_2_write.execute_stateful_alu(meta.mar);
    //count(hit_2, meta.mar);
}

blackbox stateful_alu heap_2_reset {
    reg                     : heap_2;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_2_reset() {
    heap_2_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_2_rmw {
    reg                     : heap_2;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_2_rmw() {
    count_2_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_2 {
    reg                     : heap_2;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_2() {
    count_minread_2.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_3 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_3 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_3_write {
    reg                     : heap_3;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_3_write() {
    heap_3_write.execute_stateful_alu(meta.mar);
    //count(hit_3, meta.mar);
}

blackbox stateful_alu heap_3_reset {
    reg                     : heap_3;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_3_reset() {
    heap_3_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_3_rmw {
    reg                     : heap_3;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_3_rmw() {
    count_3_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_3 {
    reg                     : heap_3;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_3() {
    count_minread_3.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_4 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_4 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_4_write {
    reg                     : heap_4;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_4_write() {
    heap_4_write.execute_stateful_alu(meta.mar);
    //count(hit_4, meta.mar);
}

blackbox stateful_alu heap_4_reset {
    reg                     : heap_4;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_4_reset() {
    heap_4_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_4_rmw {
    reg                     : heap_4;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_4_rmw() {
    count_4_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_4 {
    reg                     : heap_4;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_4() {
    count_minread_4.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_5 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_5 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_5_write {
    reg                     : heap_5;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_5_write() {
    heap_5_write.execute_stateful_alu(meta.mar);
    //count(hit_5, meta.mar);
}

blackbox stateful_alu heap_5_reset {
    reg                     : heap_5;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_5_reset() {
    heap_5_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_5_rmw {
    reg                     : heap_5;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_5_rmw() {
    count_5_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_5 {
    reg                     : heap_5;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_5() {
    count_minread_5.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_6 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_6 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_6_write {
    reg                     : heap_6;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_6_write() {
    heap_6_write.execute_stateful_alu(meta.mar);
    //count(hit_6, meta.mar);
}

blackbox stateful_alu heap_6_reset {
    reg                     : heap_6;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_6_reset() {
    heap_6_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_6_rmw {
    reg                     : heap_6;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_6_rmw() {
    count_6_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_6 {
    reg                     : heap_6;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_6() {
    count_minread_6.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_7 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_7 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_7_write {
    reg                     : heap_7;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_7_write() {
    heap_7_write.execute_stateful_alu(meta.mar);
    //count(hit_7, meta.mar);
}

blackbox stateful_alu heap_7_reset {
    reg                     : heap_7;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_7_reset() {
    heap_7_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_7_rmw {
    reg                     : heap_7;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_7_rmw() {
    count_7_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_7 {
    reg                     : heap_7;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_7() {
    count_minread_7.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_8 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_8 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_8_write {
    reg                     : heap_8;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_8_write() {
    heap_8_write.execute_stateful_alu(meta.mar);
    //count(hit_8, meta.mar);
}

blackbox stateful_alu heap_8_reset {
    reg                     : heap_8;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_8_reset() {
    heap_8_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_8_rmw {
    reg                     : heap_8;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_8_rmw() {
    count_8_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_8 {
    reg                     : heap_8;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_8() {
    count_minread_8.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_9 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_9 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_9_write {
    reg                     : heap_9;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_9_write() {
    heap_9_write.execute_stateful_alu(meta.mar);
    //count(hit_9, meta.mar);
}

blackbox stateful_alu heap_9_reset {
    reg                     : heap_9;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_9_reset() {
    heap_9_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_9_rmw {
    reg                     : heap_9;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_9_rmw() {
    count_9_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_9 {
    reg                     : heap_9;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_9() {
    count_minread_9.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_10 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_10 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_10_write {
    reg                     : heap_10;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_10_write() {
    heap_10_write.execute_stateful_alu(meta.mar);
    //count(hit_10, meta.mar);
}

blackbox stateful_alu heap_10_reset {
    reg                     : heap_10;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_10_reset() {
    heap_10_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_10_rmw {
    reg                     : heap_10;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_10_rmw() {
    count_10_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_10 {
    reg                     : heap_10;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_10() {
    count_minread_10.execute_stateful_alu_from_hash(heap_index);
}*/

register heap_11 {
    width           : 32;
    instance_count  : 65536;
}

counter hit_11 {
    type            : packets;
    instance_count  : 65536;
}

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

blackbox stateful_alu heap_11_write {
    reg                     : heap_11;
    condition_lo            : register_lo == 0;
    condition_hi            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : meta.mar;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : meta.mbr;
    output_predicate        : condition_lo or condition_hi;
    output_value            : 1;
    output_dst              : meta.disabled;
}

action memory_11_write() {
    heap_11_write.execute_stateful_alu(meta.mar);
    //count(hit_11, meta.mar);
}

blackbox stateful_alu heap_11_reset {
    reg                     : heap_11;
    condition_lo            : register_lo == meta.mar;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 0;
}

action memory_11_reset() {
    heap_11_reset.execute_stateful_alu(meta.mar);
}

blackbox stateful_alu count_11_rmw {
    reg                     : heap_11;
    /*condition_lo            : meta.reset == 0;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : register_lo + 1;
    update_lo_2_predicate   : not condition_lo;
    update_lo_2_value       : 0;*/
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action counter_11_rmw() {
    count_11_rmw.execute_stateful_alu(meta.mar);
}

/*blackbox stateful_alu count_minread_11 {
    reg                     : heap_11;
    condition_hi            : register_lo < meta.mbr;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : 1;
    output_predicate        : condition_hi;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action lru_minread_11() {
    count_minread_11.execute_stateful_alu_from_hash(heap_index);
}*/

// Stage independent actions

action skip() {}

action drop() {
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
} 

action cancel_drop() {
    bit_and(eg_intr_md_for_oport.drop_ctl, eg_intr_md_for_oport.drop_ctl, 6);
}

action duplicate() {
    modify_field(meta.duplicate, 1);
}

action loop_init() {
    modify_field(meta.loop, 1);
}

action loop_end() {
    modify_field(meta.loop, 0);
}

action complete() {
    modify_field(meta.complete, 1);
    modify_field(as.flag_done, 1);
}

action copy_mbr2_mbr() {
    modify_field(meta.mbr, meta.mbr2);
}

action copy_mbr_mbr2() {
    modify_field(meta.mbr2, meta.mbr);
}

action acc_load() {
    modify_field(as.acc, meta.mbr);
}

action acc2_load() {
    modify_field(as.acc2, meta.mbr);
}

action mark_processed_packet() {
    modify_field(as.flag_redirect, 1);
}

action unmark_processed_packet() {
    modify_field(as.flag_redirect, 0);
}

action enable_execution() {
    bit_and(meta.disabled, meta.disabled, 126);
}

action return_to_sender() {
    swap(ipv4.srcAddr, ipv4.dstAddr);
    swap(ethernet.srcAddr, ethernet.dstAddr);
    add_to_field(udp.len, 6);
    modify_field(as.flag_rts, 1);
    modify_field(meta.rts, 1);
}

action memfault() {
    modify_field(as.flag_mfault, 1);
    return_to_sender();
}

field_list l4_5tuple_list {
    ipv4.protocol;
    ipv4.srcAddr;
    ipv4.dstAddr;
    udp.dstPort;
    udp.srcPort;
}

field_list_calculation l4_5tuple_hash {
    input           { l4_5tuple_list; }
    algorithm       : identity;
    output_width    : 16;
}

action hash5tuple() {
    modify_field_with_hash_based_offset(meta.mar, 0, l4_5tuple_hash, 16);
}

field_list id_list {
    as.id;
}

field_list_calculation id_list_hash {
    input           { id_list; }
    algorithm       : identity;
    output_width    : 16;
}

action hash_id() {
    modify_field_with_hash_based_offset(meta.mar, 0, id_list_hash, 65536);
}

action set_port(mirror_id) {
    modify_field(meta.rtsid, mirror_id);
    modify_field(as.flag_rts, 1);
}

action get_random_port() {
    modify_field(meta.mbr, 0, 3);
}

action goto_aux() {
    modify_field(as.flag_aux, 1);
}

field_list mar_list {
    meta.mbr;
}

// Stage dependent actions

action mar_load_1() {
    modify_field(meta.mar, ap[0].arg);
}

action mar_add_1() {
    add_to_field(meta.mar, ap[0].arg);
}

action mar_equals_1() {
    bit_xor(meta.mbr, meta.mar, ap[0].arg);
}

action mbr_load_1() {
    modify_field(meta.mbr, ap[0].arg);
}

action mbr_add_1() {
    add_to_field(meta.mbr, ap[0].arg);
}

action mbr_subtract_1() {
    subtract_from_field(meta.mbr, ap[0].arg);
}

action bit_and_mbr_mar_1() {
    bit_and(meta.mar, meta.mbr, ap[0].arg);
}

action mbr2_load_1() {
    modify_field(meta.mbr2, ap[0].arg);
}

action jump_1() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[0].goto);
}

action attempt_rejoin_1() {
    bit_xor(meta.disabled, meta.pc, ap[0].goto);
}

action bit_and_mbr_1() {
    bit_and(meta.mbr, meta.mbr, ap[0].arg);
}

field_list_calculation mar_list_hash_1 {
    input           { mar_list; }
    algorithm       : crc_16_en_13757;
    output_width    : 13;
}

action hashmar_1() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_1, 8192);
}

action mar_load_2() {
    modify_field(meta.mar, ap[1].arg);
}

action mar_add_2() {
    add_to_field(meta.mar, ap[1].arg);
}

action mar_equals_2() {
    bit_xor(meta.mbr, meta.mar, ap[1].arg);
}

action mbr_load_2() {
    modify_field(meta.mbr, ap[1].arg);
}

action mbr_add_2() {
    add_to_field(meta.mbr, ap[1].arg);
}

action mbr_subtract_2() {
    subtract_from_field(meta.mbr, ap[1].arg);
}

action bit_and_mbr_mar_2() {
    bit_and(meta.mar, meta.mbr, ap[1].arg);
}

action mbr2_load_2() {
    modify_field(meta.mbr2, ap[1].arg);
}

action jump_2() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[1].goto);
}

action attempt_rejoin_2() {
    bit_xor(meta.disabled, meta.pc, ap[1].goto);
}

action bit_and_mbr_2() {
    bit_and(meta.mbr, meta.mbr, ap[1].arg);
}

field_list_calculation mar_list_hash_2 {
    input           { mar_list; }
    algorithm       : crc_16_dds_110;
    output_width    : 13;
}

action hashmar_2() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_2, 8192);
}

action mar_load_3() {
    modify_field(meta.mar, ap[2].arg);
}

action mar_add_3() {
    add_to_field(meta.mar, ap[2].arg);
}

action mar_equals_3() {
    bit_xor(meta.mbr, meta.mar, ap[2].arg);
}

action mbr_load_3() {
    modify_field(meta.mbr, ap[2].arg);
}

action mbr_add_3() {
    add_to_field(meta.mbr, ap[2].arg);
}

action mbr_subtract_3() {
    subtract_from_field(meta.mbr, ap[2].arg);
}

action bit_and_mbr_mar_3() {
    bit_and(meta.mar, meta.mbr, ap[2].arg);
}

action mbr2_load_3() {
    modify_field(meta.mbr2, ap[2].arg);
}

action jump_3() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[2].goto);
}

action attempt_rejoin_3() {
    bit_xor(meta.disabled, meta.pc, ap[2].goto);
}

action bit_and_mbr_3() {
    bit_and(meta.mbr, meta.mbr, ap[2].arg);
}

field_list_calculation mar_list_hash_3 {
    input           { mar_list; }
    algorithm       : crc_16_dect;
    output_width    : 13;
}

action hashmar_3() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_3, 8192);
}

action mar_load_4() {
    modify_field(meta.mar, ap[3].arg);
}

action mar_add_4() {
    add_to_field(meta.mar, ap[3].arg);
}

action mar_equals_4() {
    bit_xor(meta.mbr, meta.mar, ap[3].arg);
}

action mbr_load_4() {
    modify_field(meta.mbr, ap[3].arg);
}

action mbr_add_4() {
    add_to_field(meta.mbr, ap[3].arg);
}

action mbr_subtract_4() {
    subtract_from_field(meta.mbr, ap[3].arg);
}

action bit_and_mbr_mar_4() {
    bit_and(meta.mar, meta.mbr, ap[3].arg);
}

action mbr2_load_4() {
    modify_field(meta.mbr2, ap[3].arg);
}

action jump_4() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[3].goto);
}

action attempt_rejoin_4() {
    bit_xor(meta.disabled, meta.pc, ap[3].goto);
}

action bit_and_mbr_4() {
    bit_and(meta.mbr, meta.mbr, ap[3].arg);
}

field_list_calculation mar_list_hash_4 {
    input           { mar_list; }
    algorithm       : crc_16_dnp;
    output_width    : 13;
}

action hashmar_4() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_4, 8192);
}

action mar_load_5() {
    modify_field(meta.mar, ap[4].arg);
}

action mar_add_5() {
    add_to_field(meta.mar, ap[4].arg);
}

action mar_equals_5() {
    bit_xor(meta.mbr, meta.mar, ap[4].arg);
}

action mbr_load_5() {
    modify_field(meta.mbr, ap[4].arg);
}

action mbr_add_5() {
    add_to_field(meta.mbr, ap[4].arg);
}

action mbr_subtract_5() {
    subtract_from_field(meta.mbr, ap[4].arg);
}

action bit_and_mbr_mar_5() {
    bit_and(meta.mar, meta.mbr, ap[4].arg);
}

action mbr2_load_5() {
    modify_field(meta.mbr2, ap[4].arg);
}

action jump_5() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[4].goto);
}

action attempt_rejoin_5() {
    bit_xor(meta.disabled, meta.pc, ap[4].goto);
}

action bit_and_mbr_5() {
    bit_and(meta.mbr, meta.mbr, ap[4].arg);
}

field_list_calculation mar_list_hash_5 {
    input           { mar_list; }
    algorithm       : crc_16_genibus;
    output_width    : 13;
}

action hashmar_5() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_5, 8192);
}

action mar_load_6() {
    modify_field(meta.mar, ap[5].arg);
}

action mar_add_6() {
    add_to_field(meta.mar, ap[5].arg);
}

action mar_equals_6() {
    bit_xor(meta.mbr, meta.mar, ap[5].arg);
}

action mbr_load_6() {
    modify_field(meta.mbr, ap[5].arg);
}

action mbr_add_6() {
    add_to_field(meta.mbr, ap[5].arg);
}

action mbr_subtract_6() {
    subtract_from_field(meta.mbr, ap[5].arg);
}

action bit_and_mbr_mar_6() {
    bit_and(meta.mar, meta.mbr, ap[5].arg);
}

action mbr2_load_6() {
    modify_field(meta.mbr2, ap[5].arg);
}

action jump_6() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[5].goto);
}

action attempt_rejoin_6() {
    bit_xor(meta.disabled, meta.pc, ap[5].goto);
}

action bit_and_mbr_6() {
    bit_and(meta.mbr, meta.mbr, ap[5].arg);
}

field_list_calculation mar_list_hash_6 {
    input           { mar_list; }
    algorithm       : crc_16_maxim;
    output_width    : 13;
}

action hashmar_6() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_6, 8192);
}

action mar_load_7() {
    modify_field(meta.mar, ap[6].arg);
}

action mar_add_7() {
    add_to_field(meta.mar, ap[6].arg);
}

action mar_equals_7() {
    bit_xor(meta.mbr, meta.mar, ap[6].arg);
}

action mbr_load_7() {
    modify_field(meta.mbr, ap[6].arg);
}

action mbr_add_7() {
    add_to_field(meta.mbr, ap[6].arg);
}

action mbr_subtract_7() {
    subtract_from_field(meta.mbr, ap[6].arg);
}

action bit_and_mbr_mar_7() {
    bit_and(meta.mar, meta.mbr, ap[6].arg);
}

action mbr2_load_7() {
    modify_field(meta.mbr2, ap[6].arg);
}

action jump_7() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[6].goto);
}

action attempt_rejoin_7() {
    bit_xor(meta.disabled, meta.pc, ap[6].goto);
}

action bit_and_mbr_7() {
    bit_and(meta.mbr, meta.mbr, ap[6].arg);
}

field_list_calculation mar_list_hash_7 {
    input           { mar_list; }
    algorithm       : crc_16_riello;
    output_width    : 13;
}

action hashmar_7() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_7, 8192);
}

action mar_load_8() {
    modify_field(meta.mar, ap[7].arg);
}

action mar_add_8() {
    add_to_field(meta.mar, ap[7].arg);
}

action mar_equals_8() {
    bit_xor(meta.mbr, meta.mar, ap[7].arg);
}

action mbr_load_8() {
    modify_field(meta.mbr, ap[7].arg);
}

action mbr_add_8() {
    add_to_field(meta.mbr, ap[7].arg);
}

action mbr_subtract_8() {
    subtract_from_field(meta.mbr, ap[7].arg);
}

action bit_and_mbr_mar_8() {
    bit_and(meta.mar, meta.mbr, ap[7].arg);
}

action mbr2_load_8() {
    modify_field(meta.mbr2, ap[7].arg);
}

action jump_8() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[7].goto);
}

action attempt_rejoin_8() {
    bit_xor(meta.disabled, meta.pc, ap[7].goto);
}

action bit_and_mbr_8() {
    bit_and(meta.mbr, meta.mbr, ap[7].arg);
}

field_list_calculation mar_list_hash_8 {
    input           { mar_list; }
    algorithm       : crc_16_usb;
    output_width    : 13;
}

action hashmar_8() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_8, 8192);
}

action mar_load_9() {
    modify_field(meta.mar, ap[8].arg);
}

action mar_add_9() {
    add_to_field(meta.mar, ap[8].arg);
}

action mar_equals_9() {
    bit_xor(meta.mbr, meta.mar, ap[8].arg);
}

action mbr_load_9() {
    modify_field(meta.mbr, ap[8].arg);
}

action mbr_add_9() {
    add_to_field(meta.mbr, ap[8].arg);
}

action mbr_subtract_9() {
    subtract_from_field(meta.mbr, ap[8].arg);
}

action bit_and_mbr_mar_9() {
    bit_and(meta.mar, meta.mbr, ap[8].arg);
}

action mbr2_load_9() {
    modify_field(meta.mbr2, ap[8].arg);
}

action jump_9() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[8].goto);
}

action attempt_rejoin_9() {
    bit_xor(meta.disabled, meta.pc, ap[8].goto);
}

action bit_and_mbr_9() {
    bit_and(meta.mbr, meta.mbr, ap[8].arg);
}

field_list_calculation mar_list_hash_9 {
    input           { mar_list; }
    algorithm       : crc_16_teledisk;
    output_width    : 13;
}

action hashmar_9() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_9, 8192);
}

action mar_load_10() {
    modify_field(meta.mar, ap[9].arg);
}

action mar_add_10() {
    add_to_field(meta.mar, ap[9].arg);
}

action mar_equals_10() {
    bit_xor(meta.mbr, meta.mar, ap[9].arg);
}

action mbr_load_10() {
    modify_field(meta.mbr, ap[9].arg);
}

action mbr_add_10() {
    add_to_field(meta.mbr, ap[9].arg);
}

action mbr_subtract_10() {
    subtract_from_field(meta.mbr, ap[9].arg);
}

action bit_and_mbr_mar_10() {
    bit_and(meta.mar, meta.mbr, ap[9].arg);
}

action mbr2_load_10() {
    modify_field(meta.mbr2, ap[9].arg);
}

action jump_10() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[9].goto);
}

action attempt_rejoin_10() {
    bit_xor(meta.disabled, meta.pc, ap[9].goto);
}

action bit_and_mbr_10() {
    bit_and(meta.mbr, meta.mbr, ap[9].arg);
}

field_list_calculation mar_list_hash_10 {
    input           { mar_list; }
    algorithm       : crc_16_mcrf4xx;
    output_width    : 13;
}

action hashmar_10() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_10, 8192);
}

action mar_load_11() {
    modify_field(meta.mar, ap[10].arg);
}

action mar_add_11() {
    add_to_field(meta.mar, ap[10].arg);
}

action mar_equals_11() {
    bit_xor(meta.mbr, meta.mar, ap[10].arg);
}

action mbr_load_11() {
    modify_field(meta.mbr, ap[10].arg);
}

action mbr_add_11() {
    add_to_field(meta.mbr, ap[10].arg);
}

action mbr_subtract_11() {
    subtract_from_field(meta.mbr, ap[10].arg);
}

action bit_and_mbr_mar_11() {
    bit_and(meta.mar, meta.mbr, ap[10].arg);
}

action mbr2_load_11() {
    modify_field(meta.mbr2, ap[10].arg);
}

action jump_11() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[10].goto);
}

action attempt_rejoin_11() {
    bit_xor(meta.disabled, meta.pc, ap[10].goto);
}

action bit_and_mbr_11() {
    bit_and(meta.mbr, meta.mbr, ap[10].arg);
}

field_list_calculation mar_list_hash_11 {
    input           { mar_list; }
    algorithm       : crc_16_t10_dif;
    output_width    : 13;
}

action hashmar_11() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_11, 8192);
}

//#maractions

// >>>>>>>>>>>>>>>>> [EXECUTE] <<<<<<<<<<<<<<<<<< //

action step_1() {
    modify_field(ap[0].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_1 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_1;
    }
}

action step_2() {
    modify_field(ap[1].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_2 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_2;
    }
}

action step_3() {
    modify_field(ap[2].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_3 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_3;
    }
}

action step_4() {
    modify_field(ap[3].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_4 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_4;
    }
}

action step_5() {
    modify_field(ap[4].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_5 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_5;
    }
}

action step_6() {
    modify_field(ap[5].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_6 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_6;
    }
}

action step_7() {
    modify_field(ap[6].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_7 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_7;
    }
}

action step_8() {
    modify_field(ap[7].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_8 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_8;
    }
}

action step_9() {
    modify_field(ap[8].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_9 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_9;
    }
}

action step_10() {
    modify_field(ap[9].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_10 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_10;
    }
}

action step_11() {
    modify_field(ap[10].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_11 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_11;
    }
}

table execute_1 {
    reads {
        ap[0].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_1;
        mar_load_1;
        mbr_load_1;
        mbr2_load_1;
        mbr_add_1;
        mar_add_1;
        mbr_subtract_1;
        bit_and_mbr_mar_1;
        memory_1_read;
		memory_1_write;
        memory_1_reset;
        jump_1;
        attempt_rejoin_1;
        mar_equals_1;
        bit_and_mbr_1;
        counter_1_rmw;
    }
}

table execute_2 {
    reads {
        ap[1].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_2;
        mar_load_2;
        mbr_load_2;
        mbr2_load_2;
        mbr_add_2;
        mar_add_2;
        mbr_subtract_2;
        bit_and_mbr_mar_2;
        memory_2_read;
		memory_2_write;
        memory_2_reset;
        jump_2;
        attempt_rejoin_2;
        mar_equals_2;
        bit_and_mbr_2;
        counter_2_rmw;
    }
}

table execute_3 {
    reads {
        ap[2].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_3;
        mar_load_3;
        mbr_load_3;
        mbr2_load_3;
        mbr_add_3;
        mar_add_3;
        mbr_subtract_3;
        bit_and_mbr_mar_3;
        memory_3_read;
		memory_3_write;
        memory_3_reset;
        jump_3;
        attempt_rejoin_3;
        mar_equals_3;
        bit_and_mbr_3;
        counter_3_rmw;
    }
}

table execute_4 {
    reads {
        ap[3].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_4;
        mar_load_4;
        mbr_load_4;
        mbr2_load_4;
        mbr_add_4;
        mar_add_4;
        mbr_subtract_4;
        bit_and_mbr_mar_4;
        memory_4_read;
		memory_4_write;
        memory_4_reset;
        jump_4;
        attempt_rejoin_4;
        mar_equals_4;
        bit_and_mbr_4;
        counter_4_rmw;
    }
}

table execute_5 {
    reads {
        ap[4].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_5;
        mar_load_5;
        mbr_load_5;
        mbr2_load_5;
        mbr_add_5;
        mar_add_5;
        mbr_subtract_5;
        bit_and_mbr_mar_5;
        memory_5_read;
		memory_5_write;
        memory_5_reset;
        jump_5;
        attempt_rejoin_5;
        mar_equals_5;
        bit_and_mbr_5;
        counter_5_rmw;
    }
}

table execute_6 {
    reads {
        ap[5].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_6;
        mar_load_6;
        mbr_load_6;
        mbr2_load_6;
        mbr_add_6;
        mar_add_6;
        mbr_subtract_6;
        bit_and_mbr_mar_6;
        memory_6_read;
		memory_6_write;
        memory_6_reset;
        jump_6;
        attempt_rejoin_6;
        mar_equals_6;
        bit_and_mbr_6;
        counter_6_rmw;
    }
}

table execute_7 {
    reads {
        ap[6].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_7;
        mar_load_7;
        mbr_load_7;
        mbr2_load_7;
        mbr_add_7;
        mar_add_7;
        mbr_subtract_7;
        bit_and_mbr_mar_7;
        memory_7_read;
		memory_7_write;
        memory_7_reset;
        jump_7;
        attempt_rejoin_7;
        mar_equals_7;
        bit_and_mbr_7;
        counter_7_rmw;
    }
}

table execute_8 {
    reads {
        ap[7].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_8;
        mar_load_8;
        mbr_load_8;
        mbr2_load_8;
        mbr_add_8;
        mar_add_8;
        mbr_subtract_8;
        bit_and_mbr_mar_8;
        memory_8_read;
		memory_8_write;
        memory_8_reset;
        jump_8;
        attempt_rejoin_8;
        mar_equals_8;
        bit_and_mbr_8;
        counter_8_rmw;
    }
}

table execute_9 {
    reads {
        ap[8].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_9;
        mar_load_9;
        mbr_load_9;
        mbr2_load_9;
        mbr_add_9;
        mar_add_9;
        mbr_subtract_9;
        bit_and_mbr_mar_9;
        memory_9_read;
		memory_9_write;
        memory_9_reset;
        jump_9;
        attempt_rejoin_9;
        mar_equals_9;
        bit_and_mbr_9;
        counter_9_rmw;
    }
}

table execute_10 {
    reads {
        ap[9].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_10;
        mar_load_10;
        mbr_load_10;
        mbr2_load_10;
        mbr_add_10;
        mar_add_10;
        mbr_subtract_10;
        bit_and_mbr_mar_10;
        memory_10_read;
		memory_10_write;
        memory_10_reset;
        jump_10;
        attempt_rejoin_10;
        mar_equals_10;
        bit_and_mbr_10;
        counter_10_rmw;
    }
}

table execute_11 {
    reads {
        ap[10].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        //meta.lru_target     : range;
    }
    actions {
        skip;
        complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        //copy_mbr2_mbr;
        //copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        hashmar_11;
        mar_load_11;
        mbr_load_11;
        mbr2_load_11;
        mbr_add_11;
        mar_add_11;
        mbr_subtract_11;
        bit_and_mbr_mar_11;
        memory_11_read;
		memory_11_write;
        memory_11_reset;
        jump_11;
        attempt_rejoin_11;
        mar_equals_11;
        bit_and_mbr_11;
        counter_11_rmw;
    }
}

// >>>>>>>>>>>>>>>>> [RECIRCULATE] <<<<<<<<<<<<<<<<<< //

field_list cycle_metadata {
    meta.lru_target;
    meta.rtsid;
    meta.pc;
    meta.loop;
    meta.disabled;
    meta.complete;
    meta.quota_start;
    meta.quota_end;
    meta.mar;
    meta.mbr;
    meta.mbr2;
    meta.mirror_sess;
    meta.mirror_type;
    meta.skipped;
    meta.burnt_ipv4;
    meta.burnt_udp;
    meta.rts;
    meta.cycles;
}

// re-circulate if program not complete or port change required

action reset_aux() {
    modify_field(as.flag_aux, 0);
    modify_field(meta.skipped, 0);
}

action set_mirror(dst) {
    modify_field(meta.mirror_type, 1);
    modify_field(meta.mirror_sess, dst);
    clone_egress_pkt_to_egress(dst, cycle_metadata);
    add_to_field(ipv4.identification, 1000);
}

action cycle_aux(dst) {
    set_mirror(dst);
    reset_aux();
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
    subtract_from_field(ipv4.ttl, 1);
}

action cycle_clone_aux(dst) {
    set_mirror(dst);
    reset_aux();
    subtract_from_field(ipv4.ttl, 1);
}

action cycle(dst) {
    set_mirror(dst);
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
    subtract_from_field(ipv4.ttl, 1);
}

action cycle_clone(dst) {
    set_mirror(dst);
    subtract_from_field(ipv4.ttl, 1);
}

action cycle_redirect() {
    set_mirror(meta.rtsid);
    modify_field(as.flag_rts, 0);
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
}

table progress {
    reads {
        as.flag_rts     : exact;
        as.flag_aux     : exact;
        meta.skipped    : exact;
        meta.complete   : exact;
        meta.duplicate  : exact;
        meta.cycles     : range;
    }
    actions {
        cycle;
        cycle_clone;
        cycle_redirect;
        cycle_aux;
        cycle_clone_aux;
    }
}

action update_lengths() {
    subtract_from_field(ipv4.totalLen, meta.burnt_ipv4);
    subtract_from_field(udp.len, meta.burnt_udp);
}

action update_burnt() {
    subtract_from_field(meta.burnt_ipv4, 6);
    modify_field(meta.rts, 0);
}

table lenupdate {
    reads {
        meta.rts        : exact;
        meta.complete   : exact;
    }
    actions {
        update_lengths;
        update_burnt;
    }
}

action update_cycles() {
    subtract_from_field(meta.cycles, 1);
}

table cycleupdate {
    actions {
        update_cycles;
    }
}

control egress {
    apply(proceed_1);
	apply(execute_1) { hit {
		apply(proceed_2);
		apply(execute_2) { hit {
			apply(proceed_3);
			apply(execute_3) { hit {
				apply(proceed_4);
				apply(execute_4) { hit {
					apply(proceed_5);
					apply(execute_5) { hit {
						apply(proceed_6);
						apply(execute_6) { hit {
							apply(proceed_7);
							apply(execute_7) { hit {
								apply(proceed_8);
								apply(execute_8) { hit {
									apply(proceed_9);
									apply(execute_9) { hit {
										apply(proceed_10);
										apply(execute_10) { hit {
											apply(proceed_11);
											apply(execute_11) { hit {
											}}
										}}
									}}
								}}
							}}
						}}
					}}
				}}
			}}
		}}
	}}
    apply(cycleupdate);
    apply(progress);
    apply(lenupdate);
}