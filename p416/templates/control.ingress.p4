control Ingress(
    inout ingress_headers_t                          hdr,
    inout active_metadata_t                          meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    <register-defs>

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
#ifdef BYPASS_EGRESS
        ig_tm_md.bypass_egress = 1;
#endif
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table ipv4_host {
        key = { hdr.ipv4.dst_addr : exact; }
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

    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { send; drop; }

        default_action = send(64);
        size           = IPV4_LPM_SIZE;
    }

    // actions

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
    }

    action set_port() {
        ig_tm_md.ucast_egress_port = (bit<9>) meta.mbr;
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
        if (hdr.ipv4.isValid()) {
            if (ipv4_host.apply().miss) {
                ipv4_lpm.apply();
            }
        }
        <generated-ctrlflow>
    }
}