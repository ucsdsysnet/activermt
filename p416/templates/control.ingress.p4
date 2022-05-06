control Ingress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    <register-defs>

    <hash-defs>

    Counter<bit<64>, bit<32>>(1, CounterType_t.PACKETS_AND_BYTES) overall_stats;

    action bypass_egress() {
        ig_tm_md.bypass_egress = 1;
        hdr.meta.setInvalid();
    }

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        overall_stats.count(0);
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table ipv4_host {
        key = { 
            hdr.ipv4.dst_addr   : exact; 
        }
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
        ig_tm_md.ucast_egress_port = (bit<9>) hdr.meta.mbr;
    }

    action complete() {
        hdr.meta.complete = 1;
    }

    action uncomplete() {
        hdr.meta.complete = 0;
    }

    action acc1_load() {
        hdr.ih.acc = hdr.meta.mbr;
    }

    action acc2_load() {
        hdr.ih.acc2 = hdr.meta.mbr;
    }

    action copy_mbr2_mbr1() {
        hdr.meta.mbr2 = hdr.meta.mbr;
    }

    action copy_mbr1_mbr2() {
        hdr.meta.mbr = hdr.meta.mbr2;
    }

    action mark_packet() {
        hdr.ih.flag_marked = 1;
    }

    action memfault() {
        hdr.ih.flag_mfault = 1;
        hdr.ih.acc = hdr.meta.mar;
        complete();
        rts();
    }

    action min_mbr1_mbr2() {
        hdr.meta.mbr = (hdr.meta.mbr <= hdr.meta.mbr2 ? hdr.meta.mbr : hdr.meta.mbr2);
    }

    action min_mbr2_mbr1() {
        hdr.meta.mbr2 = (hdr.meta.mbr2 <= hdr.meta.mbr ? hdr.meta.mbr2 : hdr.meta.mbr);
    }

    action mbr1_equals_mbr2() {
        hdr.meta.mbr = hdr.meta.mbr ^ hdr.meta.mbr2;
    }

    action copy_mar_mbr() {
        hdr.meta.mar = hdr.meta.mbr;
    }

    action copy_mbr_mar() {
        hdr.meta.mbr = hdr.meta.mar;
    }

    action bit_and_mar_mbr() {
        hdr.meta.mar = hdr.meta.mar & hdr.meta.mbr;
    }

    action mar_add_mbr() {
        hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr;
    }

    action copy_acc_mbr() {
        hdr.ih.acc = hdr.meta.mbr;
    }

    // GENERATED: ACTIONS

    <generated-actions-defs>

    // GENERATED: TABLES

    <generated-tables>

    // resource monitoring

    // quota enforcement

    Random<bit<16>>() rnd;
    Counter<bit<32>, bit<32>>(65536, CounterType_t.PACKETS_AND_BYTES) activep4_stats;

    action set_quotas(bit<8> circulations) {
        hdr.meta.cycles = circulations;
        activep4_stats.count((bit<32>)hdr.ih.fid);
    }

    action get_quotas(bit<16> alloc_id, bit<16> mem_start, bit<16> mem_end, bit<16> curr_bw) {
        hdr.ih.acc = mem_start;
        hdr.ih.acc2 = mem_end;
        hdr.ih.data = curr_bw;
        hdr.ih.data2 = alloc_id;
        hdr.ih.flag_allocated = 1;
        rts();
        bypass_egress();
    }

    table quotas {
        key     = {
            hdr.ih.fid              : exact;
            hdr.ih.flag_reqalloc    : exact;
            meta.randnum            : range;
        }
        actions = {
            set_quotas;
            get_quotas;
        }
    }

    action get_seq_vaddr_params(bit<16> addrmask, bit<16> offset) {
        meta.seq_addr = hdr.ih.seq & addrmask;
        meta.seq_offset = offset;
    }

    table seq_vaddr {
        key     = {
            hdr.ih.fid  : exact;
        }
        actions = {
            get_seq_vaddr_params;
        }
    }

    Register<bit<8>, bit<32>>(32w65536) seqmap;

    RegisterAction<bit<8>, bit<32>, bit<8>>(seqmap) seq_update = {
        void apply(inout bit<8> value, out bit<8> rv) {
            rv = value;
            value = meta.set_clr_seq;
        }
    };

    action seq_addr_translate() {
        meta.seq_addr = meta.seq_addr + meta.seq_offset;
    }

    action check_prior_exec() {
        hdr.meta.complete = (bit<1>) seq_update.execute((bit<32>) meta.seq_addr);
    }

    // control flow

    apply {
        if(meta.eof == 1) {
            hdr.ih.flag_done = 1;
        }
        seq_vaddr.apply();
        seq_addr_translate();
        check_prior_exec();
        if(meta.is_active != 1) {
            bypass_egress();
        }
        meta.randnum = rnd.get();
        quotas.apply();
        <generated-ctrlflow>
        if (hdr.ipv4.isValid()) {
            ipv4_host.apply();
        }
        //hdr.ipv4.total_len = hdr.ipv4.total_len - meta.instr_count;
    }
}