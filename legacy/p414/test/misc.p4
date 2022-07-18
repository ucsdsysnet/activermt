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
        result  : 32;
        addr    : 32;
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

register heap {
    width           : 64;
    instance_count  : 65536;
}

blackbox stateful_alu heap_read {
    reg                 : heap;
    condition_lo        : register_lo == meta.addr;
    condition_hi        : meta.result > 0;
    output_predicate    : condition_lo or condition_hi;
    output_dst          : meta.result;
    output_value        : register_hi;
}

field_list addr_list {
    meta.addr;
}

field_list_calculation addr_list_hash {
    input           { addr_list; }
    algorithm       : crc_16_dnp;
    output_width    : 16;
}

action memory_read() {
    heap_read.execute_stateful_alu_from_hash(addr_list_hash);
}

table dummy {
    reads {
        ethernet.srcAddr    : exact;
    }
    actions {
        compute;
        memory_read;
    }
}

control ingress {
    apply(dummy);
}

control egress {}