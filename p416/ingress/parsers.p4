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

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(pkt.lookahead<bit<32>>()) {
            0x12345678  : parse_active_ih;
            default     : parse_ipv4;
        }
    }

    /*state parse_l3 {
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }*/

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
            5..15   : parse_tcp_options;
            default : accept;
        }
    }

    state parse_tcp_options {
        pkt.extract(hdr.tcpopts, (bit<32>)(hdr.tcp.data_offset - 5) * 32);
        transition accept;
    }

    state parse_active_ih {
        pkt.extract(hdr.ih);
        meta.is_active = 1;
        meta.set_clr_seq = 1;
        transition select(hdr.ih.flag_done) {
            1   : accept;
            _   : parse_active_instruction;
        }
    }

    state parse_active_instruction {
        pkt.extract(hdr.instr.next);
        transition select(hdr.instr.last.opcode) {
            0x0     : parse_ipv4;
            _       : parse_active_instruction;
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
        pkt.emit(hdr);
    }
}