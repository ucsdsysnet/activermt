parser EgressParser(
    packet_in                       pkt,
    out egress_headers_t            hdr,
    out eg_metadata_t               meta,
    
    out egress_intrinsic_metadata_t eg_intr_md
) {
    Checksum() tcp_checksum;

    state start {
        pkt.extract(eg_intr_md);
        transition parse_metadata;
    }

    state parse_metadata {
        pkt.extract(hdr.meta);
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
        transition parse_active_ih;
    }

    state parse_active_ih {
        pkt.extract(hdr.ih);
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

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    Checksum() ipv4_checksum;
    Checksum() tcp_checksum;
    Mirror() mirror;
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
                hdr.instr[7].arg,
                hdr.instr[8].flags,
                hdr.instr[8].goto,
                hdr.instr[8].opcode,
                hdr.instr[8].arg,
                hdr.instr[9].flags,
                hdr.instr[9].goto,
                hdr.instr[9].opcode,
                hdr.instr[9].arg,*/
                meta.chksum_tcp
            });
        }
        if(eg_dprsr_md.mirror_type == MIRROR_TYPE_E2E) {
            mirror.emit<eg_port_mirror_h>(
                hdr.meta.egr_mir_ses,
                {
                    /*meta.mirror_header_type,
                    meta.mirror_header_info,
                    meta.ingress_port,
                    meta.mirror_session,
                    meta.ingress_mac_tstamp,
                    meta.ingress_global_tstamp*/
                    hdr.meta.pkt_type
                }
            );
        }
        pkt.emit(hdr);
    }
}