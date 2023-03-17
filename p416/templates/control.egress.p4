<generated-third-party-macros>

control Egress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    <register-defs>

    <hash-defs>

    action fetch_queue() {
        hdr.meta.mbr = (bit<32>)eg_intr_md.enq_qdepth;
    }

    action fetch_qdelay() {
        hdr.meta.mbr = hdr.meta.qdelay;
    }

    action fetch_pktcount() {
        hdr.meta.mbr = hdr.meta.ig_pktcount;
    }

    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    action complete() {
        hdr.meta.complete = 1;
    }

    action mark_termination() {
        hdr.ih.flag_done = 1;
    }

    action skip() {}

    action rts() {
        // TODO re-circulate
    }

    action set_port() {
        meta.port_change = 1;
        meta.egress_port = (bit<9>)hdr.meta.mbr;
    }

    action load_5_tuple_tcp() {
        // NOP
    }

    action load_tcp_flags() {
        // NOP
        // hdr.meta.mbr[15:0] = hdr.tcp.flags;
    }

    // GENERATED: ACTIONS

    <generated-actions-defs>

    // GENERATED: TABLES

    <generated-tables>

    Counter<bit<32>, bit<32>>(65538, CounterType_t.PACKETS_AND_BYTES) activep4_stats;

    action recirculate() {
        meta.mirror_sessid = hdr.meta.mirror_sessid;
        eg_dprsr_md.mirror_type = 1;
        hdr.meta.mirror_iter = hdr.meta.mirror_iter - 1;
    }

    action ack(bit<10> sessid) {
        /*mac_addr_t  tmp_mac;
        tmp_mac = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp_mac;*/
        meta.mirror_sessid = sessid;
        eg_dprsr_md.mirror_type = 1;
        hdr.meta.remap = 0;
        hdr.ih.flag_remapped = 1;
    }

    table mirror_ack {
        key = {
            hdr.meta.remap          : exact;
            hdr.meta.ingress_port   : exact;
        }
        actions = {
            ack;
        }
    }

    action set_mirror(bit<10> sessid) {
        hdr.meta.mirror_en = 1;
        hdr.meta.mirror_sessid = sessid;
    }

    table mirror_cfg {
        key = {
            meta.egress_port  : exact;
        }
        actions = {
            set_mirror;
        }
    }

    // Third-Party

    <third-party-eg-defs>
    
    // control flow
    
    apply {
        <third-party-eg-cf>
        mirror_cfg.apply();
        hdr.meta.eg_timestamp = (bit<32>)eg_prsr_md.global_tstamp[31:0];
        hdr.meta.qdelay = hdr.meta.eg_timestamp - hdr.meta.ig_timestamp;
        <generated-ctrlflow>
        activep4_stats.count((bit<32>)hdr.ih.fid);
        if(hdr.meta.mirror_iter > 0 && (hdr.meta.complete == 0 || meta.port_change == 1)) {
            recirculate();
            if(hdr.meta.duplicate == 0) {
                drop();
            } else {
                hdr.meta.duplicate = 0;
            }
        } else {
            if(mirror_ack.apply().miss) {
                hdr.meta.setInvalid();
            }
        }
    }
}