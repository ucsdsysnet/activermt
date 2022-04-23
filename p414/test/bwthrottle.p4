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
        fwdid       : 16;
        mirror_type : 1;
        mirror_id   : 10;
        mirror_sess : 10;
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

/*field_list ipv4_checksum_list {
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
}*/

action setegr(port, fwdid) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
    modify_field(meta.fwdid, fwdid);
}

table forward {
    reads {
        ipv4.dstAddr    : lpm;
    }
    actions {
        setegr;
    }
}

action redirect(addr) {
    modify_field(ipv4.dstAddr, addr);
}

table reroute {
    reads {
        ipv4.dstAddr    : exact;
    }
    actions {
        redirect;
    }
}

control ingress {
    apply(reroute);
    apply(forward);
}

field_list cycle_metadata {
    meta.fwdid;
}

action recirc() {
    modify_field(meta.mirror_type, 1);
    modify_field(meta.mirror_sess, meta.fwdid);
    clone_egress_pkt_to_egress(meta.fwdid, cycle_metadata);
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
    subtract_from_field(ipv4.ttl, 1);
}

table repeat {
    reads {
        ipv4.ttl    : range;
    }
    actions {
        recirc;
    }
}

control egress {
    apply(repeat);
}