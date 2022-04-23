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
        color   : 8;
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

meter traffic_monitor {
    type            : bytes;
    instance_count  : 256;
}

action trafficupdate() {
    execute_meter(traffic_monitor, 0, meta.color);
}

table traffic {
    actions {
        trafficupdate;
    }
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

register bloom_meter {
    width           : 8;
    instance_count  : 1;
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
    bloom_meter_filter.execute_stateful_alu(0);
}

table filter_meter {
    reads {
        meta.color          : exact;
    }
    actions {
        dofilter_meter;
    }
}

field_list meter_params {
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

control ingress {
    apply(forward);
    apply(traffic);
    apply(filter_meter);
    apply(monitor);
}

control egress {}