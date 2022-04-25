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

header_type metadata_t {
    fields {
        result  : 16;
    }
}

header ethernet_t           ethernet;

metadata metadata_t         meta;

parser start {
    extract(ethernet);
    return ingress;
}

action compute() {
    min(meta.result, meta.result, ethernet.etherType);
}

table dummy {
    reads {
        ethernet.srcAddr    : exact;
    }
    actions {
        compute;
    }
}

control ingress {
    apply(dummy);
}

control egress {}