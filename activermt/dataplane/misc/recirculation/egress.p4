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
        /*hdr.meta.iter = 0;
        hdr.meta.mirror_en = 0;*/
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
    action recirculate() {
        meta.mirror_sessid = hdr.meta.mirror_sessid;
        eg_dprsr_md.mirror_type = 1;
        hdr.meta.iter = hdr.meta.iter - 1;
    }

    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    apply {
        if(hdr.meta.iter > 0) {
            recirculate();
            drop();
        } 
    }
}

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    Mirror() mirror;

    apply {
        if(eg_dprsr_md.mirror_type == 1) {
            mirror.emit(meta.mirror_sessid);
        }
        pkt.emit(hdr);
    }
}