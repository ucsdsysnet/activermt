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

/*register buckets {
    width           : 32;
    instance_count  : 65536;
}

blackbox stateful_alu bucket_set {
    reg                     : buckets;
    condition_hi            : register_lo == 1;
    update_hi_1_predicate   : condition_hi;
    update_hi_1_value       : register_hi + 1;
    update_lo_1_predicate   : true;
    update_lo_1_value       : 1;
}

blackbox stateful_alu bucket_reset {
    reg                     : buckets;
    update_lo_1_predicate   : true;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : true;
    update_hi_1_value       : register_hi;
}

action bucket_inc() {
    bucket_set.execute_stateful_alu(as.id);
}

action bucket_dec() {
    bucket_reset.execute_stateful_alu(as.id);
}

table bucketupdate {
    reads {
        as.acc      : exact;
    }
    actions {
        bucket_inc;
        bucket_dec;
    }
}

action applymask() {
    bit_and(as.id, as.id, 65535);
}*/

action setegr(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
}

table forward {
    reads {
        ipv4.dstAddr    : lpm;
    }
    actions {
        setegr;
    }
}

register flows {
    width           : 32;
    instance_count  : 65536;
}

blackbox stateful_alu write_flow_id {
    reg                     : flows;
    condition_lo            : register_lo == as.id or register_lo == 0;
    update_hi_1_predicate   : condition_lo;
    update_hi_1_value       : 1;
    update_lo_1_predicate   : condition_lo;
    update_lo_1_value       : as.id;
    output_predicate        : not condition_lo;
    output_dst              : as.flag_marked;
    output_value            : 1;
}

blackbox stateful_alu clear_flow_id {
    reg                     : flows;
    update_lo_1_predicate   : true;
    update_lo_1_value       : 0;
    update_hi_1_predicate   : true;
    update_hi_1_value       : 0;
}

action install_flow() {
    write_flow_id.execute_stateful_alu(meta.mar);
}

action clear_flow() {
    clear_flow_id.execute_stateful_alu(meta.mar);
    drop();
}

table flowinstall {
    reads {
        as.acc  : exact;
    }
    actions {
        install_flow;
        clear_flow;
    }
}

field_list flowhash_hashlist {
    as.id;
}

field_list_calculation flowhash {
    input           { flowhash_hashlist; }
    algorithm       : identity;
    output_width    : 16;
}

action hashflow() {
    modify_field_with_hash_based_offset(meta.mar, 0, flowhash, 65536);
}

table flowhashing {
    reads {
        as.fid      : exact;
    }
    actions {
        hashflow;
    }
}

action apply_pagemask(pagemask) {
    bit_and(meta.mar, meta.mar, pagemask);
}

table pagemask {
    reads {
        as.fid      : exact;
    }
    actions {
        apply_pagemask;
    }
}

action apply_pageoffset(pageoffset) {
    add(meta.mar, meta.mar, pageoffset);
}

table pageoffset {
    reads {
        as.fid      : exact;
    }
    actions {
        apply_pageoffset;
    }
}

control ingress {
    if(valid(as)) {
        //apply(bucketupdate);
        apply(flowhashing);
        apply(pagemask);
        apply(pageoffset);
        apply(flowinstall);
    }
    apply(forward);
}

control egress {}