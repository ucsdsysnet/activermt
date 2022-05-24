parser EgressParser(
    packet_in                       pkt,
    out egress_headers_t            hdr,
    out eg_metadata_t               meta,
    
    out egress_intrinsic_metadata_t eg_intr_md
) {
    state start {
        pkt.extract(eg_intr_md);
        transition parse_metadata;
    }

    state parse_metadata {
        pkt.extract(hdr.meta);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.AP4    : parse_active_ih;
            _                   : accept;
        }
    }

    state parse_active_ih {
        pkt.extract(hdr.ih);
        transition select(hdr.ih.flag_done) {
            1   : accept;
            _   : parse_active_instruction;
        }
    }

    state parse_active_instruction {
        pkt.extract(hdr.instr.next);
        transition select(hdr.instr.last.opcode) {
            0x0     : accept;
            _       : parse_active_instruction;
        }
    }
}

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    Checksum() ipv4_checksum;
    Mirror() mirror;
    apply {
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