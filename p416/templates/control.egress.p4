control Egress(
    inout egress_headers_t                             hdr,
    inout active_metadata_t                            meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    <register-defs>

    <hash-defs>

    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    action skip() {}

    action rts() {
        mac_addr_t  tmp_mac;
        ipv4_addr_t tmp_ipv4;
        tmp_mac = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp_mac;
        tmp_ipv4 = hdr.ipv4.src_addr;
        hdr.ipv4.src_addr = hdr.ipv4.dst_addr;
        hdr.ipv4.dst_addr = tmp_ipv4;
        // TODO re-circulate
    }

    action set_port() {
        // TODO re-circulate
    }

    action complete() {
        meta.complete = 1;
    }

    action uncomplete() {
        meta.complete = 0;
    }

    action acc1_load() {
        hdr.ih.acc = meta.mbr;
    }

    action acc2_load() {
        hdr.ih.acc2 = meta.mbr;
    }

    action copy_mbr2_mbr1() {
        meta.mbr2 = meta.mbr;
    }

    action copy_mbr1_mbr2() {
        meta.mbr = meta.mbr2;
    }

    action mark_packet() {
        hdr.ih.flag_marked = 1;
    }

    action memfault() {
        hdr.ih.flag_mfault = 1;
        hdr.ih.acc = meta.mar;
        complete();
        rts();
    }

    action min_mbr1_mbr2() {
        meta.mbr = (meta.mbr <= meta.mbr2 ? meta.mbr : meta.mbr2);
    }

    action min_mbr2_mbr1() {
        meta.mbr2 = (meta.mbr2 <= meta.mbr ? meta.mbr2 : meta.mbr);
    }

    action mbr1_equals_mbr2() {
        meta.mbr = meta.mbr ^ meta.mbr2;
    }

    action copy_mar_mbr() {
        meta.mar = meta.mbr;
    }

    action copy_mbr_mar() {
        meta.mbr = meta.mar;
    }

    action bit_and_mar_mbr() {
        meta.mar = meta.mar & meta.mbr;
    }

    action mar_add_mbr() {
        meta.mar = meta.mar + meta.mbr;
    }

    action copy_acc_mbr() {
        hdr.ih.acc = meta.mbr;
    }

    // GENERATED: ACTIONS

    <generated-actions-defs>

    // GENERATED: TABLES

    <generated-tables>

    // control flow
    
    apply {
        <generated-ctrlflow>
    }
}