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

header_type metadata_t {
    fields {
        digest  : 8;
    }
}

header ethernet_t           ethernet;
header ipv4_t               ipv4;

metadata metadata_t         meta;

parser start {
    extract(ethernet);
    return select(ethernet.etherType) {
        0x0800 : parse_ipv4;
        default: ingress;
    }
}

parser parse_ipv4 {
    extract(ipv4);
    return ingress;
}

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

counter traffic {
    type    : packets_and_bytes;
    direct  : forward;
}

control ingress {
    apply(forward);
}

control egress {}