#include <core.p4>
#include <tna.p4>

#define ALPHA   1

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

struct ig_metadata_t {}

struct eg_metadata_t {
    bit<32>     buf;
    bit<32>     alpha;
    bit<32>     omega;
    bit<16>     addr;
    bit<16>     offset;
}

struct ingress_headers_t {
    ethernet_h                                  ethernet;
}

struct egress_headers_t {
    ethernet_h                                  ethernet;
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
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
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
        //if(hdr.ethernet.isValid()) mac_host.apply();
        send(1);
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
    Hash<bit<16>>(HashAlgorithm_t.CRC16) crc16;

    Register<bit<32>, bit<32>>(32w65536) reg;

    RegisterAction<bit<32>, bit<32>, bit<32>>(reg) update_reg = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            /*bit<32> tmp = obj;
            obj = obj + meta.alpha;
            rv = obj;
            if(obj > meta.omega) {
                obj = meta.omega;
                rv = obj;
            } else if(obj >= meta.buf) {
                obj = tmp;
                rv = 0;
            }*/
            rv = 0;
            if(obj < meta.buf) {
                obj = obj + 1;
                rv = obj;
            } else if(obj < meta.omega) {
                obj = meta.omega;
                rv = obj;
            }
        }
    };

    action update_stat_reg() {
        meta.buf = update_reg.execute((bit<32>)meta.addr);
    }

    action compute_address_hash() {
        meta.addr = crc16.get({ hdr.ethernet.dst_addr });
    }

    action compute_address_offset() {
        meta.addr = (bit<16>)meta.addr[7:0] + meta.offset;
    }

    apply {
        meta.omega = 0xFFFF;
        compute_address_hash();
        compute_address_offset();
        update_stat_reg();
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