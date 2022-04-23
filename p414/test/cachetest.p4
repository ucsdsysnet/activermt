#ifdef __TARGET_TOFINO__
#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>
#include <tofino/primitives.p4>
#include <tofino/stateful_alu_blackbox.p4>
#else
#error This program is intended to compile for Tofino P4 architecture only
#endif

header_type ethernet_t {
    fields {
        dstAddr   : 48;
        srcAddr   : 48;
        etherType : 16;
    }
}

header_type ipv4_t {
    fields {
        version        : 4;
        ihl            : 4;
        diffserv       : 8;
        totalLen       : 16;
        identification : 16;
        flags          : 3;
        fragOffset     : 13;
        ttl            : 8;
        protocol       : 8;
        hdrChecksum    : 16;
        srcAddr        : 32;
        dstAddr        : 32;
    }
}

header_type udp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        len     : 16;
        cksum   : 16;
    }
}

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
        flag_marked     : 1;
        flag_aux        : 1;
        flag_ack        : 1;
        flag_done       : 1;
        flag_mfault     : 1;
        flag_exceeded   : 1;
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

header_type metadata_t {
    fields {
        mar             : 16;
        mbr             : 16;
        mincount        : 16;
        addr_1          : 16;
        addr_2          : 16;
        addr_3          : 16;
        addr_4          : 16;
    }
}

header ethernet_t           ethernet;
header ipv4_t               ipv4;
header udp_t                udp;
header pktgen_ts_t          ts;
header active_state_t       as;
header metadata_t           meta;

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
    return ingress;
}

counter active_traffic {
    type            : packets_and_bytes;
    instance_count  : 256;
}

action skipexec() {
    bypass_egress();
}

table completioncheck {
    reads {
        as.flag_done    : exact;
    }
    actions {
        skipexec;
    }
}

action setegr(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
    modify_field(as.flag_done, 1);
}

table forward {
    reads {
        ipv4.dstAddr    : lpm;
    }
    actions {
        setegr;
    }
}

field_list objhash_hashlist {
    as.freq;
}

field_list_calculation objhash {
    input           { objhash_hashlist; }
    algorithm       : crc_16;
    output_width    : 16;
}

action hashobj() {
    modify_field_with_hash_based_offset(meta.mar, 0, objhash, 65536);
    count(active_traffic, as.fid);
}

table objhashing {
    reads {
        as.acc2      : exact;
    }
    actions {
        hashobj;
    }
}

action applymask(pagemask) {
    bit_and(meta.mar, meta.mar, pagemask);
}

table add_pagemask {
    reads {
        as.fid      : exact;
    }
    actions {
        applymask;
    }
}

action addoffset(offset) {
    add(meta.mar, meta.mar, offset);
}

table add_pageoffset {
    reads {
        as.fid      : exact;
    }
    actions {
        addoffset;
    }
}

register cache_key {
    width           : 16;
    instance_count  : 65536;
}

register cache_value {
    width           : 16;
    instance_count  : 65536;
}

blackbox stateful_alu read_object_key {
    reg                     : cache_key;
    output_predicate        : true;
    output_dst              : as.acc;
    output_value            : register_lo;
}

blackbox stateful_alu read_object_value {
    reg                     : cache_value;
    output_predicate        : true;
    output_dst              : as.acc;
    output_value            : register_lo;
}

blackbox stateful_alu write_object_key {
    reg                     : cache_key;
    update_lo_1_predicate   : true;
    update_lo_1_value       : as.freq;
}

blackbox stateful_alu write_object_value {
    reg                     : cache_value;
    update_lo_1_predicate   : true;
    update_lo_1_value       : as.acc;
}

action readkey() {
    read_object_key.execute_stateful_alu(meta.mar);
}

action readvalue() {
    read_object_value.execute_stateful_alu(meta.mar);
}

action writekey() {
    write_object_key.execute_stateful_alu(meta.mar);
}

action writevalue() {
    write_object_value.execute_stateful_alu(meta.mar);
}

table cachekey {
    reads {
        as.acc2     : exact;
    }
    actions {
        readkey;
        writekey;
    }
}

action cmpkey() {
    bit_xor(meta.mbr, as.acc, as.freq);
}

table keyeq {
    reads {
        as.acc2     : exact;
    }
    actions {
        cmpkey;
    }
}

table cachevalue {
    reads {
        meta.mbr    : exact;
        as.acc2     : exact;
    }
    actions {
        readvalue;
        writevalue;
    }
}

action cachemiss() {
    modify_field(as.id, 1);
}

table cachehitmiss {
    reads {
        as.acc2     : exact;
        as.acc      : exact;
    }
    actions {
        cachemiss;
    }
}

action rts() {
    modify_field(ipv4.dstAddr, ipv4.srcAddr);
    modify_field(ethernet.dstAddr, ethernet.srcAddr);
    modify_field(meta.mbr, 0);
}

table route {
    reads {
        as.id       : exact;
        as.acc2     : exact;
    }
    actions {
        rts;
    }
}

action return_allocation(alloc_id, memstart, memend) {
    modify_field(as.id, alloc_id);
    modify_field(as.acc, memstart);
    modify_field(as.acc2, memend);
    modify_field(as.flag_allocated, 1);
    rts();
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

control ingress {
    if(valid(as)) {
        apply(getalloc);
        apply(completioncheck) {
            miss {
                apply(objhashing);
                apply(add_pagemask);
                apply(add_pageoffset);
                apply(cachekey);
                apply(keyeq);
                apply(cachevalue);
                apply(cachehitmiss);
                apply(route);
            }
        }
    }
    apply(forward);
}

field_list cms_hashlist {
    as.freq;
}

field_list_calculation cmshash_1 {
    input           { cms_hashlist; }
    algorithm       : crc_16_dect;
    output_width    : 16;
}

action hashcms_1() {
    modify_field_with_hash_based_offset(meta.addr_1, 0, cmshash_1, 65536);
}

table cmsprep_1 {
    reads {
        as.fid      : exact;
        as.acc2     : exact;
    }
    actions {
        hashcms_1;
    }
}

action applypagemask_1(pagemask) {
    bit_and(meta.addr_1, meta.addr_1, pagemask);
}

action applypageoffset_1(pageoffset) {
    add(meta.addr_1, meta.addr_1, pageoffset);
}

table cms_addrmask_1 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypagemask_1;
    }
}

table cms_addroffset_1 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypageoffset_1;
    }
}

register cms_1 {
    width           : 16;
    instance_count  : 65536;
}

blackbox stateful_alu count_1 {
    reg                     : cms_1;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    output_predicate        : true;
    output_dst              : meta.mincount;
    output_value            : register_lo;
}

action cms_count_1() {
    count_1.execute_stateful_alu(meta.addr_1);
}

table cmscount_1 {
    reads {
        as.acc2     : exact;
    }
    actions {
        cms_count_1;
    }
}

field_list_calculation cmshash_2 {
    input           { cms_hashlist; }
    algorithm       : crc_16_dnp;
    output_width    : 16;
}

action hashcms_2() {
    modify_field_with_hash_based_offset(meta.addr_2, 0, cmshash_2, 65536);
}

table cmsprep_2 {
    reads {
        as.fid      : exact;
        as.acc2     : exact;
    }
    actions {
        hashcms_2;
    }
}

action applypagemask_2(pagemask) {
    bit_and(meta.addr_2, meta.addr_2, pagemask);
}

action applypageoffset_2(pageoffset) {
    add(meta.addr_2, meta.addr_2, pageoffset);
}

table cms_addrmask_2 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypagemask_2;
    }
}

table cms_addroffset_2 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypageoffset_2;
    }
}

register cms_2 {
    width           : 16;
    instance_count  : 65536;
}

blackbox stateful_alu count_2 {
    reg                     : cms_2;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action cms_count_2() {
    count_2.execute_stateful_alu(meta.addr_2);
}

table cmscount_2 {
    reads {
        as.acc2     : exact;
    }
    actions {
        cms_count_2;
    }
}

field_list_calculation cmshash_3 {
    input           { cms_hashlist; }
    algorithm       : crc_16_genibus;
    output_width    : 16;
}

action hashcms_3() {
    modify_field_with_hash_based_offset(meta.addr_3, 0, cmshash_3, 65536);
    min(meta.mincount, meta.mincount, meta.mbr);
}

table cmsprep_3 {
    reads {
        as.fid      : exact;
        as.acc2     : exact;
    }
    actions {
        hashcms_3;
    }
}

action applypagemask_3(pagemask) {
    bit_and(meta.addr_3, meta.addr_3, pagemask);
}

action applypageoffset_3(pageoffset) {
    add(meta.addr_3, meta.addr_3, pageoffset);
}

table cms_addrmask_3 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypagemask_3;
    }
}

table cms_addroffset_3 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypageoffset_3;
    }
}

register cms_3 {
    width           : 16;
    instance_count  : 65536;
}

blackbox stateful_alu count_3 {
    reg                     : cms_3;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action cms_count_3() {
    count_3.execute_stateful_alu(meta.addr_3);
}

table cmscount_3 {
    reads {
        as.acc2     : exact;
    }
    actions {
        cms_count_3;
    }
}

field_list_calculation cmshash_4 {
    input           { cms_hashlist; }
    algorithm       : crc_16_usb;
    output_width    : 16;
}

action hashcms_4() {
    modify_field_with_hash_based_offset(meta.addr_4, 0, cmshash_4, 65536);
    min(meta.mincount, meta.mincount, meta.mbr);
}

table cmsprep_4 {
    reads {
        as.fid      : exact;
        as.acc2     : exact;
    }
    actions {
        hashcms_4;
    }
}

action applypagemask_4(pagemask) {
    bit_and(meta.addr_4, meta.addr_4, pagemask);
}

action applypageoffset_4(pageoffset) {
    add(meta.addr_4, meta.addr_4, pageoffset);
}

table cms_addrmask_4 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypagemask_4;
    }
}

table cms_addroffset_4 {
    reads {
        as.fid      : exact;
    }
    actions {
        applypageoffset_4;
    }
}

register cms_4 {
    width           : 16;
    instance_count  : 65536;
}

blackbox stateful_alu count_4 {
    reg                     : cms_4;
    update_lo_1_predicate   : true;
    update_lo_1_value       : register_lo + 1;
    output_predicate        : true;
    output_dst              : meta.mbr;
    output_value            : register_lo;
}

action cms_count_4() {
    count_4.execute_stateful_alu(meta.addr_4);
}

table cmscount_4 {
    reads {
        as.acc2     : exact;
    }
    actions {
        cms_count_4;
    }
}

action storecmscount() {
    min(as.acc2, meta.mincount, meta.mbr);
    //modify_field(as.flag_marked, 1);
}

table storecms {
    reads {
        as.acc2     : exact;
    }
    actions {
        storecmscount;
    }
}

control egress {
    if(valid(as)) {
        apply(cmsprep_1);
        apply(cmsprep_2);
        apply(cmsprep_3);
        apply(cmsprep_4);
        apply(cms_addrmask_1);
        apply(cms_addrmask_2);
        apply(cms_addrmask_3);
        apply(cms_addrmask_4);
        apply(cms_addroffset_1);
        apply(cms_addroffset_2);
        apply(cms_addroffset_3);
        apply(cms_addroffset_4);
        apply(cmscount_1);
        apply(cmscount_2);
        apply(cmscount_3);
        apply(cmscount_4);
        apply(storecms);
    }
}