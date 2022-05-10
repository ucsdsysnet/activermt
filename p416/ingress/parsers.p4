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
            hdr.ih.flag_redirect,
            hdr.ih.flag_igclone,
            hdr.ih.flag_bypasseg,
            hdr.ih.flag_rts,
            hdr.ih.flag_marked,
            hdr.ih.flag_aux,
            hdr.ih.flag_ack,
            hdr.ih.flag_done,
            hdr.ih.flag_mfault,
            hdr.ih.flag_exceeded,
            hdr.ih.flag_reqalloc,
            hdr.ih.flag_allocated,
            hdr.ih.flag_precache,
            hdr.ih.flag_usecache,
            hdr.ih.padding,
            hdr.ih.fid,
            hdr.ih.seq,
            hdr.ih.acc,
            hdr.ih.acc2,
            hdr.ih.data,
            hdr.ih.data2,
            hdr.ih.res
        });
        tcp_checksum.subtract_all_and_deposit(meta.chksum_tcp);
        meta.set_clr_seq = 1;
        transition select(hdr.ih.flag_done) {
            1   : accept;
            _   : check_prior_execution;
        }
    }

    state check_prior_execution {
        transition select(pkt.lookahead<bit<7>>()) {
            1   : skip_executed_instruction;
            _   : parse_active_instruction;
        }
    }

    state skip_executed_instruction {
        pkt.extract(hdr.stale.next);
        transition select(pkt.lookahead<bit<7>>()) {
            1   : skip_executed_instruction;
            _   : parse_active_instruction;
        }
    }

    state parse_active_instruction {
        pkt.extract(hdr.instr.next);
        tcp_checksum.subtract({
            hdr.instr.last.flags,
            hdr.instr.last.goto,
            hdr.instr.last.opcode,
            hdr.instr.last.arg
        });
        transition select(hdr.instr.last.opcode) {
            0x0     : mark_eof;
            default : parse_active_instruction;
        }
    }

    state mark_eof {
        meta.eof = 1;
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
        if(hdr.ih.isValid()) {
            hdr.tcp.checksum = tcp_checksum.update({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.total_len,
                hdr.ih.flag_redirect,
                hdr.ih.flag_igclone,
                hdr.ih.flag_bypasseg,
                hdr.ih.flag_rts,
                hdr.ih.flag_marked,
                hdr.ih.flag_aux,
                hdr.ih.flag_ack,
                hdr.ih.flag_done,
                hdr.ih.flag_mfault,
                hdr.ih.flag_exceeded,
                hdr.ih.flag_reqalloc,
                hdr.ih.flag_allocated,
                hdr.ih.flag_precache,
                hdr.ih.flag_usecache,
                hdr.ih.padding,
                hdr.ih.fid,
                hdr.ih.seq,
                hdr.ih.acc,
                hdr.ih.acc2,
                hdr.ih.data,
                hdr.ih.data2,
                hdr.ih.res,
                /*hdr.instr[0].flags,
                hdr.instr[0].goto,
                hdr.instr[0].opcode,
                hdr.instr[0].arg,
                hdr.instr[1].flags,
                hdr.instr[1].goto,
                hdr.instr[1].opcode,
                hdr.instr[1].arg,
                hdr.instr[2].flags,
                hdr.instr[2].goto,
                hdr.instr[2].opcode,
                hdr.instr[2].arg,
                hdr.instr[3].flags,
                hdr.instr[3].goto,
                hdr.instr[3].opcode,
                hdr.instr[3].arg,
                hdr.instr[4].flags,
                hdr.instr[4].goto,
                hdr.instr[4].opcode,
                hdr.instr[4].arg,
                hdr.instr[5].flags,
                hdr.instr[5].goto,
                hdr.instr[5].opcode,
                hdr.instr[5].arg,
                hdr.instr[6].flags,
                hdr.instr[6].goto,
                hdr.instr[6].opcode,
                hdr.instr[6].arg,
                hdr.instr[7].flags,
                hdr.instr[7].goto,
                hdr.instr[7].opcode,
                hdr.instr[7].arg,*/
                meta.chksum_tcp
            });
        }
        pkt.emit(hdr);
    }
}