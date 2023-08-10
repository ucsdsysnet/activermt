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

header cache_selector_h {
    bit<16>     fid;
}

<cache_header_definitions>

struct ig_metadata_t {
    <cache_metadata>
}

struct eg_metadata_t {
    <cache_metadata>
}

struct ingress_headers_t {
    ethernet_h              ethernet;
    cache_selector_h        cache_selector;
    <cache_header_declarations>                  
}

struct egress_headers_t {
    ethernet_h              ethernet;
    cache_selector_h        cache_selector;
    <cache_header_declarations>
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
        transition parse_cache_selector;
    }

    state parse_cache_selector {
        pkt.extract(hdr.cache_selector);
        transition select(hdr.cache_selector.fid) {
            <cache_parser_selectors>
            _   : accept;
        }
    }

    <cache_parsers>
}

control Ingress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    <register_alu_actions>

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
        size = 8096;
    }

    apply {
        if(hdr.ethernet.isValid()) {
            fwd.apply();
        }
        <alu_control>
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
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition parse_cache_selector;
    }

    state parse_cache_selector {
        pkt.extract(hdr.cache_selector);
        transition select(hdr.cache_selector.fid) {
            <cache_parser_selectors>
            _   : accept;
        }
    }

    <cache_parsers>
}

control Egress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    <register_alu_actions>
    
    apply {
        <alu_control>
    }
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