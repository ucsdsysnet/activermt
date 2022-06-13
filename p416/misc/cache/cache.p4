#include <core.p4>
#include <tna.p4>

typedef bit<48> mac_addr_t;

enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    ARP  = 0x0806
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header cache_h {
    bit<8>      rw;
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

struct ig_metadata_t {
    bit<32>     mar;
    bit<32>     mbr;
    bool        eq;
}

struct eg_metadata_t {}

struct ingress_headers_t {
    ethernet_h              ethernet;
    cache_h                 cache;                     
}

struct egress_headers_t {}

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
        transition parse_cache;
    }

    state parse_cache {
        pkt.extract(hdr.cache);
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
    Register<bit<32>, bit<32>>(32w65536) heap_key;

    RegisterAction<bit<32>, bit<32>, bit<32>>(heap_key) heap_read_key = {
        void apply(inout bit<32> value, out bit<32> rv) {
            rv = value;
        }
    };

    action memory_read_key() {
        meta.mbr = heap_read_key.execute(hdr.cache.addr);
    }

    Register<bit<32>, bit<32>>(32w65536) heap_value;

    RegisterAction<bit<32>, bit<32>, bit<32>>(heap_value) heap_read_value = {
        void apply(inout bit<32> value, out bit<32> rv) {
            rv = value;
        }
    };

    action memory_read_value() {
        meta.mbr = heap_read_value.execute(hdr.cache.addr);
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action rts() {
        mac_addr_t tmp;
        tmp = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = tmp;
    }

    table fwd {
        key     = {
            hdr.ethernet.dst_addr   : exact;
        }
        actions = {
            send;
            drop;
        }
        const default_action = drop();
    }

    action fetch_and_return() {
        memory_read_value();
        hdr.cache.value = meta.mbr;
        rts();
    }

    table fetchobj {
        key = {
            meta.eq : exact;
        }
        actions = {
            fetch_and_return;
        }
    }

    apply {
        if(hdr.ethernet.isValid()) {
            memory_read_key();
            if(meta.mbr == hdr.cache.key) meta.eq = true;
            fetchobj.apply();
            fwd.apply();
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