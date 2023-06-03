#include <core.p4>
#include <tna.p4>

#define SWITCH_ID   1

typedef bit<48> mac_addr_t;

enum bit<16> ether_type_t {
    IPV4        = 0x0800,
    ARP         = 0x0806,
    ETH_P_SNOOP = 0x83b3
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header snoop_h {
    bit<32>     pipe_id;
    bit<32>     ingress_ts;
    bit<32>     egress_ts;
    bit<32>     addr;
    bit<32>     data;
}

struct ig_metadata_t {}

struct eg_metadata_t {}

struct ingress_headers_t {
    ethernet_h              ethernet;
    snoop_h                 snoop;                 
}

struct egress_headers_t {
    ethernet_h              ethernet;
    snoop_h                 snoop;
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
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.ETH_P_SNOOP    : parse_snoop;
            _                           : accept;
        }
    }

    state parse_snoop {
        pkt.extract(hdr.snoop);
        hdr.snoop.pipe_id = (bit<32>)SWITCH_ID;
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
    Register<bit<32>, bit<32>>(32w65536) heap;

    RegisterAction<bit<32>, bit<32>, bit<32>>(heap) heap_read_ra = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            rv = obj;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(heap) heap_write_ra = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            obj = hdr.snoop.data;
        }
    };

    action heap_read() {
        hdr.snoop.data = heap_read_ra.execute(hdr.snoop.addr);
    }

    action heap_write() {
        heap_write_ra.execute(hdr.snoop.addr);
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table fwd {
        key     = {
            ig_intr_md.ingress_port : exact;
            // hdr.ethernet.dst_addr   : exact;
        }
        actions = {
            send;
            drop;
        }
        const default_action = drop();
    }

    apply {
        
        if(hdr.ethernet.isValid()) {
            fwd.apply();
        }
        
        if(hdr.snoop.isValid()) {
            if(hdr.snoop.ingress_ts == 0) {
                hdr.snoop.ingress_ts = (bit<32>)ig_prsr_md.global_tstamp[31:0];
                heap_read();
            } else {
                hdr.snoop.egress_ts = (bit<32>)ig_prsr_md.global_tstamp[31:0];
                heap_write();
            }
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
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.ETH_P_SNOOP    : parse_snoop;
            _                           : accept;
        }
    }

    state parse_snoop {
        pkt.extract(hdr.snoop);
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
    apply {
        if(hdr.snoop.isValid()) {
            // hdr.snoop.egress_ts = (bit<32>)eg_prsr_md.global_tstamp[31:0];
            hdr.snoop.addr = 0;
        }
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