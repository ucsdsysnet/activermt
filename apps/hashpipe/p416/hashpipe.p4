#include <core.p4>
#include <tna.p4>

typedef bit<48> mac_addr_t;

enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    ARP  = 0x0806,
    AP4  = 0x83B2
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

struct ig_metadata_t {
    bit<32> key;
    bit<32> prev_key;
    bit<32> count;
}

struct eg_metadata_t {}

struct ingress_headers_t {
    ethernet_h                                  ethernet;
}

struct egress_headers_t {
    ethernet_h                                  ethernet;
}

struct counter_obj_t {
    bit<32>     key;
    bit<32>     count;
}

parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition accept;
    }
}

control Ingress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    Register<counter_obj_t, bit<32>>(32w65536) key_0;
    Register<counter_obj_t, bit<32>>(32w65536) value_0;

    RegisterAction<counter_obj_t, bit<32>, bit<32>>(key_0) insert_key_0 = {
        void apply(inout counter_obj_t obj, out bit<32> rv) {
            rv = obj.key;
            obj.key = meta.key;
        }
    };

    RegisterAction<counter_obj_t, bit<32>, bit<32>>(value_0) insert_count_0 = {
        void apply(inout counter_obj_t obj, out bit<32> rv) {
            rv = obj.count;
            if(meta.key == obj.key) {
                obj.count = obj.count + 1;
            } else {
                obj.key = meta.key;
                obj.count = 1;
            }
        }
    };

    action stage_0_key() {
        meta.prev_key = insert_key_0.execute(0);
    }

    action stage_0_count() {
        meta.count = insert_count_0.execute(0);
    }

    Register<counter_obj_t, bit<32>>(32w65536) key_1;
    Register<counter_obj_t, bit<32>>(32w65536) value_1;

    RegisterAction<counter_obj_t, bit<32>, bit<32>>(key_1) update_key_1 = {
        void apply(inout counter_obj_t obj, out bit<32> rv) {
            if(meta.count < obj.count) {
                obj.key = meta.key;
                obj.count = meta.count;
            }
            rv = obj.key;
        }
    };

    RegisterAction<counter_obj_t, bit<32>, bit<32>>(value_1) update_count_1 = {
        void apply(inout counter_obj_t obj, out bit<32> rv) {
            if(meta.count < obj.count) {
                obj.count = meta.count;
            }
            rv = obj.count;
        }
    };

    action stage_1_key() {
        meta.prev_key = update_key_1.execute(0);
    }

    action stage_1_count() {
        meta.count = update_count_1.execute(0);
    }

    action send(PortId_t port, mac_addr_t mac) {
        ig_tm_md.ucast_egress_port = port;
        hdr.ethernet.dst_addr = mac;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table mac_host {
        key = {
            hdr.ethernet.src_addr   : exact;
        }
        actions = {
            send;
            drop;
        }
    }

    apply {
        if(hdr.ethernet.isValid()) mac_host.apply();
        stage_0_key();
        stage_0_count();
        if(meta.prev_key != meta.key) {
            meta.key = meta.prev_key;
            stage_1_key();
            stage_1_count();
        }
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    apply {
        pkt.emit(hdr);
    }
}

parser EgressParser(
    packet_in                       pkt,
    out egress_headers_t            hdr,
    out eg_metadata_t               meta,
    
    out egress_intrinsic_metadata_t eg_intr_md
) {
    state start {
        pkt.extract(eg_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition accept;
    }
}

control Egress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    apply {}
}

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    apply {
        pkt.emit(hdr);
    }
}

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;