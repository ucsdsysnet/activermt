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

    action send(PortId_t port, mac_addr_t mac) {
        ig_tm_md.ucast_egress_port = port;
        hdr.ethernet.dst_addr = mac;
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

    table vroute {
        key = {
            meta.port_change    : exact;
            meta.vport          : exact;
        }
        actions = {
            send;
        }
    }

    // actions

    action mark_termination() {
        hdr.ih.flag_done = 1;
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
    }

    action set_port() {
        meta.port_change = 1;
        meta.vport = (bit<16>)hdr.meta.mbr;
    }

    action load_5_tuple_tcp() {
        hdr.meta.hash_data_0 = hdr.ipv4.src_addr;
        hdr.meta.hash_data_1 = hdr.ipv4.dst_addr;
        hdr.meta.hash_data_2 = (bit<32>)0x0006;
        hdr.meta.hash_data_3 = (bit<32>)hdr.tcp.src_port;
        hdr.meta.hash_data_4 = (bit<32>)hdr.tcp.dst_port;
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

    action get_quotas(bit<32> alloc_id, bit<32> mem_start, bit<32> mem_end, bit<32> curr_bw) {
        hdr.data.data_0 = mem_start;
        hdr.data.data_1 = mem_end;
        hdr.data.data_2 = curr_bw;
        hdr.data.data_3 = alloc_id;
        hdr.ih.flag_allocated = 1;
        rts();
        bypass_egress();
    }

    table quotas {
        key     = {
            hdr.ih.fid              : exact;
            hdr.ih.flag_reqalloc    : exact;
            hdr.meta.randnum        : range;
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
        //hdr.meta.complete = (bit<1>) seq_update.execute((bit<32>) meta.seq_addr);
    }

    // control flow

    apply {
        //meta.set_clr_seq = 1;
        seq_vaddr.apply();
        seq_addr_translate();
        check_prior_exec();
        if(!hdr.ih.isValid()) {
            bypass_egress();
        }
        hdr.meta.randnum = rnd.get();
        quotas.apply();
        <generated-ctrlflow>
        if (hdr.ipv4.isValid()) {
            overall_stats.count(0);
            if(vroute.apply().miss) {
                ipv4_host.apply();
            }
        }
    }
}