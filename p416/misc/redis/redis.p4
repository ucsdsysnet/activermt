#include <core.p4>
#include <tna.p4>

typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;

enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    ARP  = 0x0806
}

enum bit<8> ipv4_protocol_t {
    TCP = 0x06
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header ipv4_h {
    bit<4>          version;
    bit<4>          ihl;
    bit<8>          diffserv;
    bit<16>         total_len;
    bit<16>         identification;
    bit<3>          flags;
    bit<13>         frag_offset;
    bit<8>          ttl;
    ipv4_protocol_t protocol;
    bit<16>         hdr_checksum;
    ipv4_addr_t     src_addr;
    ipv4_addr_t     dst_addr;
}

header tcp_h {
    bit<16>     src_port;
    bit<16>     dst_port;
    bit<32>     seq_no;
    bit<32>     ack_no;
    bit<4>      data_offset;
    bit<3>      res;
    bit<3>      ecn;
    bit<6>      ctrl;
    bit<16>     window;
    bit<16>     checksum;
    bit<16>     urgent_ptr;
}

header tcp_option_h {
    varbit<320> data;
}

header redis_array_h {
    bit<8>      FMT_ARR;
    bit<8>      arr_len;
    bit<16>     CRLF_ARR;
    bit<8>      FMT_STR_OP;
    bit<8>      str_len_op;
    bit<16>     CRLF_STR_OPLEN;
    bit<24>     op;
    bit<16>     CRLF_STR_OP;
    bit<8>      FMT_STR_KEY;
    bit<8>      str_len_key;
    bit<16>     CRLF_STR_KEY;
    bit<24>     key_pfx;
    bit<16>     key;
    bit<16>     CRLF_STR_KEYNAME;
}

header redis_array_ctd_h {
    bit<8>      FMT_STR_VALUE;
    bit<8>      str_len_value;
    bit<16>     CRLF_STR_VALUE;
    bit<48>     value;
    bit<16>     CRLF_STR_VALUENAME;
}

header redis_bulk_string_h {
    bit<8>      FMT_BSTR;
    bit<8>      str_len;
    bit<16>     CRLF_STR;
    bit<48>     msg;
    bit<16>     CRLF_STR_VALUE;
}

header redis_simple_string_h {
    bit<8>      FMT_SSTR;
    bit<16>     msg;
    bit<16>     CRLF;
}

struct ig_metadata_t {
    bit<16>     chksum_tcp;
}

struct eg_metadata_t {}

struct ingress_headers_t {
    ethernet_h              ethernet;
    ipv4_h                  ipv4;
    tcp_h                   tcp;
    tcp_option_h            tcpopts;
    redis_array_h           redis_arr;
    redis_array_ctd_h       redis_arr_ctd;
    redis_simple_string_h   redis_sstr;
    redis_bulk_string_h     redis_bstr;                                   
}

struct egress_headers_t {}

parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
    Checksum() tcp_checksum;

    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

#ifdef PARSER_OPT
    @critical
#endif
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.IPV4   : parse_ipv4;
            _                   : accept;
        }
    }
#ifdef PARSER_OPT
    @critical
#endif

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            ipv4_protocol_t.TCP : parse_tcp;
            _                   : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        tcp_checksum.subtract({
            hdr.tcp.checksum
        });
        transition select(hdr.tcp.data_offset) {
            5..15   : parse_tcp_options;
            _       : accept;
        }
    }

    state parse_tcp_options {
        pkt.extract(hdr.tcpopts, (bit<32>)(hdr.tcp.data_offset - 5) * 32);
        transition select(hdr.tcp.data_offset) {
            5   : parse_verify_pktlen_40;
            6   : parse_verify_pktlen_44;
            7   : parse_verify_pktlen_48;
            8   : parse_verify_pktlen_52;
            9   : parse_verify_pktlen_56;
            10  : parse_verify_pktlen_60;
            11  : parse_verify_pktlen_64;
            12  : parse_verify_pktlen_68;
            13  : parse_verify_pktlen_72;
            14  : parse_verify_pktlen_76;
            15  : parse_verify_pktlen_80;
        }
    }

    state parse_verify_pktlen_40 {
        transition select(hdr.ipv4.total_len) {
            40..44  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_44 {
        transition select(hdr.ipv4.total_len) {
            44..48  : accept;
            _       : parse_redis;
        }
    }

    state parse_verify_pktlen_48 {
        transition select(hdr.ipv4.total_len) {
            48..52  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_52 {
        transition select(hdr.ipv4.total_len) {
            52..56  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_56 {
        transition select(hdr.ipv4.total_len) {
            56..60  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_60 {
        transition select(hdr.ipv4.total_len) {
            60..64  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_64 {
        transition select(hdr.ipv4.total_len) {
            64..68  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_68 {
        transition select(hdr.ipv4.total_len) {
            68..72  : accept;
            _       : parse_redis;
        }
    }
    
    state parse_verify_pktlen_72 {
        transition select(hdr.ipv4.total_len) {
            72..76  : accept;
            _       : parse_redis;
        }
    }

    state parse_verify_pktlen_76 {
        transition select(hdr.ipv4.total_len) {
            76..80  : accept;
            _       : parse_redis;
        }
    }

    state parse_verify_pktlen_80 {
        transition select(hdr.ipv4.total_len) {
            80..84  : accept;
            _       : parse_redis;
        }
    }

    state parse_redis {
        transition select(pkt.lookahead<bit<8>>()) {
            0x2a    : parse_redis_array;
            0x2b    : parse_redis_simple_string;
            0x24    : parse_redis_bulk_string;
            _       : accept;
        }
    }

    state parse_redis_simple_string {
        pkt.extract(hdr.redis_sstr);
        transition accept;
    }

    state parse_redis_array {
        pkt.extract(hdr.redis_arr);
        tcp_checksum.subtract({
            hdr.redis_arr.key
        });
        tcp_checksum.subtract_all_and_deposit(meta.chksum_tcp);
        transition select(hdr.redis_arr.arr_len) {
            2   : accept;
            3   : parse_redis_array_ctd;
            _   : accept;
        }
    }

    state parse_redis_array_ctd {
        pkt.extract(hdr.redis_arr_ctd);
        transition accept;
    }

    state parse_redis_bulk_string {
        pkt.extract(hdr.redis_bstr);
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
        ig_tm_md.bypass_egress = 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table ipv4_host {
        key = { 
            hdr.ipv4.dst_addr   : exact; 
        }
        actions = {
            send; drop;
#ifdef ONE_STAGE
            @defaultonly NoAction;
#endif
        }

#ifdef ONE_STAGE
        const default_action = NoAction();
#endif
    }

    apply {
        if (hdr.ipv4.isValid()) {
            ipv4_host.apply();
        }
        if(hdr.redis_arr.isValid()) {
            hdr.redis_arr.key = 0x3032;
        }
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    Checksum() ipv4_checksum;
    Checksum() tcp_checksum;
    apply {
        if(hdr.ipv4.isValid()) {
            hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            });
        }
        if(hdr.redis_arr.isValid()) {
            hdr.tcp.checksum = tcp_checksum.update({
                hdr.redis_arr.key,
                meta.chksum_tcp
            });
        }
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