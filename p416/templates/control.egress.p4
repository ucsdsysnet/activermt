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

    action mark_termination() {
        hdr.ih.flag_done = 1;
    }

    action skip() {}

    action rts() {
        // TODO re-circulate
    }

    action set_port() {
        // TODO re-circulate
    }

    action load_5_tuple_tcp() {
        // NOP
    }

    // GENERATED: ACTIONS

    <generated-actions-defs>

    // GENERATED: TABLES

    <generated-tables>

    Counter<bit<32>, bit<32>>(65538, CounterType_t.PACKETS_AND_BYTES) activep4_stats;

    action set_mirror(MirrorId_t mir_sess) {
        hdr.meta.egr_mir_ses = mir_sess;
        hdr.meta.pkt_type = PKT_TYPE_MIRROR;
        eg_dprsr_md.mirror_type = MIRROR_TYPE_E2E;
        drop();
    }

    table recirculation {
        key     = {
            hdr.meta.complete   : exact;
            hdr.meta.cycles     : range;
        }
        actions = {
            set_mirror;
        }
    }
    
    // control flow
    
    apply {
        hdr.meta.eg_timestamp = (bit<32>)eg_prsr_md.global_tstamp[31:0];
        hdr.meta.qdelay = hdr.meta.eg_timestamp - hdr.meta.ig_timestamp;
        <generated-ctrlflow>
        activep4_stats.count((bit<32>)hdr.ih.fid);
        recirculation.apply();
        hdr.meta.setInvalid();
    }
}