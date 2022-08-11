parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1   : parse_resubmit;
            0   : parse_port_metadata;
        }
    }

    state parse_resubmit {
        pkt.extract(meta.resubmit_data);
        hdr.meta.mbr2 = meta.resubmit_data.buf;
        hdr.meta.mar = meta.resubmit_data.addr;
        transition parse_ethernet;
    }

    state parse_metadata {
        pkt.extract(hdr.meta);
        transition parse_ethernet;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        hdr.meta.setValid();
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

    action rts() {
        mac_addr_t tmp;
        tmp = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp;
    }

    action set_data() {
        hdr.meta.mar = 1;
        hdr.meta.mbr = 1;
        hdr.meta.mbr2 = 1;
    }

    action update_data() {
        hdr.meta.mbr = hdr.meta.mbr + 1;
    }

    action set_mirror(bit<10> sessid) {
        hdr.meta.mirror_en = 1;
        hdr.meta.mirror_sessid = sessid;
        hdr.meta.iter = 3;
    }

    apply {
        send(1);
        set_mirror(1);
        /*if(ig_intr_md.resubmit_flag == 0) {
            ig_dprsr_md.resubmit_type = 1;
            rts();
            set_data();
        } else {
            update_data();
        }*/
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    Resubmit() resubmit;

    apply {
        /*if(ig_dprsr_md.resubmit_type == 1) {
            resubmit.emit<resubmit_h>({
                hdr.meta.mbr2,
                hdr.meta.mar
            });
        }*/
        pkt.emit(hdr);
    }
}