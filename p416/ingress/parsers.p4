parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
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
        transition select(hdr.tcp.data_offset) {
            5       : check_active_tcp_pkt;
            6..15   : parse_tcp_options;
            default : accept;
        }
    }

    state parse_tcp_options {
        pkt.extract(hdr.tcpopts, (bit<32>)hdr.tcp.data_offset * 32);
        transition check_active_tcp_pkt;
    }

    state check_active_tcp_pkt {
        transition select(hdr.tcp.dst_port) {
            active_port_t.TCP    : parse_active_ih;
            default : accept;
        }
    }

    state parse_active_ih {
        pkt.extract(hdr.ih);
        transition parse_active_instruction;
    }

    state parse_active_instruction {
        pkt.extract(hdr.instr.next);
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
    apply {
        pkt.emit(hdr.meta);
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.tcpopts);
        pkt.emit(hdr.ih);
    }
}