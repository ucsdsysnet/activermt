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
        hdr.meta.setValid();
        transition parse_ethernet;
    }

#ifdef PARSER_OPT
    @critical
#endif
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }
#ifdef PARSER_OPT
    @critical
#endif

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        tcp_checksum.subtract({
            hdr.ipv4.src_addr,
            hdr.ipv4.dst_addr,
            hdr.ipv4.total_len
        });
        transition select(hdr.ipv4.protocol) {
            ipv4_protocol_t.UDP : parse_udp;
            ipv4_protocol_t.TCP : parse_tcp;
            default             : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port) {
            active_port_t.UDP    : parse_active_ih;
            default : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        tcp_checksum.subtract({
            hdr.tcp.checksum
        });
        hdr.meta.chksum_tcp = tcp_checksum.get();
        transition select(hdr.tcp.data_offset) {
            5..15   : parse_tcp_options;
            default : accept;
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
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_44 {
        transition select(hdr.ipv4.total_len) {
            44..48  : accept;
            _       : parse_verify_ap4;
        }
    }

    state parse_verify_pktlen_48 {
        transition select(hdr.ipv4.total_len) {
            48..52  : accept;
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_52 {
        transition select(hdr.ipv4.total_len) {
            52..56  : accept;
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_56 {
        transition select(hdr.ipv4.total_len) {
            56..60  : accept;
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_60 {
        transition select(hdr.ipv4.total_len) {
            60..64  : accept;
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_64 {
        transition select(hdr.ipv4.total_len) {
            64..68  : accept;
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_68 {
        transition select(hdr.ipv4.total_len) {
            68..72  : accept;
            _       : parse_verify_ap4;
        }
    }
    
    state parse_verify_pktlen_72 {
        transition select(hdr.ipv4.total_len) {
            72..76  : accept;
            _       : parse_verify_ap4;
        }
    }

    state parse_verify_pktlen_76 {
        transition select(hdr.ipv4.total_len) {
            76..80  : accept;
            _       : parse_verify_ap4;
        }
    }

    state parse_verify_pktlen_80 {
        transition select(hdr.ipv4.total_len) {
            80..84  : accept;
            _       : parse_verify_ap4;
        }
    }

    state parse_verify_ap4 {
        transition select(pkt.lookahead<bit<32>>()) {
            0x12345678  : parse_active_ih;
            default     : accept;
        }
    }

    state parse_active_ih {
        pkt.extract(hdr.ih);
        meta.is_active = 1;
        tcp_checksum.subtract({
            hdr.ih.flag_rts,
            hdr.ih.acc,
            hdr.ih.acc2,
            hdr.ih.data,
            hdr.ih.data2
        });
        hdr.meta.chksum_tcp = tcp_checksum.get();
        transition parse_active_instruction;
    }

    state parse_active_instruction {
        pkt.extract(hdr.instr.next);
        tcp_checksum.subtract({
            hdr.instr.last.flags,
            hdr.instr.last.goto,
            hdr.instr.last.opcode,
            hdr.instr.last.arg
        });
        hdr.meta.chksum_tcp = tcp_checksum.get();
        transition select(hdr.instr.last.opcode) {
            0x0     : mark_eof;
            default : parse_active_instruction;
        }
    }

    state mark_eof {
        hdr.meta.eof = 1;
        transition accept;
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    Checksum() ipv4_checksum;
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
        pkt.emit(hdr.meta);
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.tcpopts);
        pkt.emit(hdr.ih);
    }
}