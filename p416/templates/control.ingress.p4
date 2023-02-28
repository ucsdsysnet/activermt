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

    action fetch_qdelay() {}

    action fetch_queue() {}

    action fetch_pktcount() {
        hdr.meta.mbr = hdr.meta.ig_pktcount;
    }

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

    action recirculate() {
        ig_dprsr_md.resubmit_type = RESUBMIT_TYPE_DEFAULT;
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

    /*table vroute {
        key = {
            meta.port_change    : exact;
            meta.vport          : exact;
        }
        actions = {
            send;
        }
    }*/

    // actions

    action mark_termination() {
        hdr.ih.flag_done = 1;
    }

    action complete() {
        hdr.meta.complete = 1;
        bypass_egress();
        mark_termination();
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
        ig_tm_md.ucast_egress_port = (bit<9>)hdr.meta.mbr;
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

    <generated-loader-defs>

    <generated-tables>

    // resource monitoring

    // quota enforcement

    Random<bit<16>>() rnd;
    Register<bit<32>, bit<32>>(32w65536) pkt_count;
    Counter<bit<64>, bit<32>>(1, CounterType_t.PACKETS_AND_BYTES) overall_stats;
    Counter<bit<32>, bit<32>>(65536, CounterType_t.PACKETS_AND_BYTES) activep4_stats;

    RegisterAction<bit<32>, bit<32>, bit<32>>(pkt_count) counter_pkts = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            obj = obj + 1; 
            rv = obj;
        }
    };

    action update_pkt_count_ap4() {
        hdr.meta.ig_pktcount = counter_pkts.execute((bit<32>)hdr.ih.fid);
    }

    action enable_recirculation() {
        hdr.meta.mirror_iter = MAX_RECIRCULATIONS;
    }

    table quota_recirc {
        key = {
            hdr.ih.fid          : exact;
            //hdr.meta.randnum    : range;
        }
        actions = {
            enable_recirculation;
        }
    }

    Register<bit<8>, bit<16>>(32w65536) seqmap;
    Hash<bit<16>>(HashAlgorithm_t.CRC16) seqhash;

    RegisterAction<bit<8>, bit<16>, bit<8>>(seqmap) seq_update = {
        void apply(inout bit<8> value, out bit<8> rv) {
            rv = value;
            value = (bit<8>)~hdr.ih.rst_seq & value;
        }
    };

    action check_prior_exec() {
        bit<16> index = seqhash.get({ hdr.ih.fid, hdr.ih.seq });
        hdr.meta.complete = (bit<1>)seq_update.execute(index);
    }

    action allocated(bit<16> allocation_id) {
        hdr.ih.flag_allocated = 1;
        hdr.ih.seq = allocation_id;
    }

    action pending() {
        hdr.ih.flag_pending = 1;
    }

    table allocation {
        key = {
            hdr.ih.fid              : exact;
            hdr.ih.flag_reqalloc    : exact;
        }
        actions = {
            allocated;
            pending;
        }
    }

    action route_malloc() {
        rts();
        bypass_egress();
    }

    table routeback {
        key = {
            hdr.ih.flag_reqalloc    : exact;
        }
        actions = {
            route_malloc;
        }
    }

    action remapped(bit<16> allocation_id) {
        hdr.meta.remap = 1;
        hdr.ih.flag_remapped = 1;
        hdr.ih.seq = allocation_id;
    }

    table remap_check { // TODO add bloom filter or equivalent.
        key = {
            hdr.ih.fid              : exact;
            hdr.ih.flag_initiated   : exact;
        }
        actions = {
            remapped;
        }
    }

    Register<bit<16>, bit<16>>(32w256) app_leader;
    
    RegisterAction<bit<16>, bit<16>, bit<16>>(app_leader) update_leader = {
        void apply(inout bit<16> obj, out bit<16> rv) {
            if((bit<16>)meta.app_instance_id < obj) {
                obj = (bit<16>)meta.app_instance_id;
            }
            rv = obj;
        }
    };

    action leader_elect() {
        meta.leader_id = (bit<8>)update_leader.execute((bit<16>)meta.app_fid);
    }

    RegisterAction<bit<16>, bit<16>, bit<16>>(app_leader) read_leader = {
        void apply(inout bit<16> obj, out bit<16> rv) {
            rv = obj;
        }
    };

    action get_leader() {
        hdr.ih.seq = (bit<16>)read_leader.execute((bit<16>)meta.app_fid);
    }

    table leader_fetch {
        key = {
            hdr.ih.flag_leader  : exact;
        }
        actions = {
            get_leader;
        }
    }

    // control flow

    apply {
        hdr.meta.ig_timestamp = (bit<32>)ig_prsr_md.global_tstamp[31:0];
        hdr.meta.randnum = rnd.get();
        if(hdr.ih.flag_preload == 1) {
            hdr.meta.mar = hdr.data.data_0;
            hdr.meta.mbr = hdr.data.data_1;
            hdr.meta.mbr2 = hdr.data.data_2;
        }
        if(hdr.ih.isValid()) {
            // leader_elect();
            // leader_fetch.apply();
            // activep4_stats.count((bit<32>)hdr.ih.fid);
            routeback.apply();
            if(hdr.ih.flag_reqalloc == 1) {
                ig_dprsr_md.digest_type = 1;
            }
            if(hdr.ih.flag_remapped == 1) {
                ig_dprsr_md.digest_type = 2;
            }
            if(allocation.apply().miss) {
                //check_prior_exec();
            }
            quota_recirc.apply();
            update_pkt_count_ap4();
        } else bypass_egress();
        <generated-loaders>
        <generated-ctrlflow>
        <generated-malloc>
        if(hdr.ipv4.isValid()) {
            ipv4_host.apply();
            /*overall_stats.count(0);
            if(vroute.apply().miss) {
                ipv4_host.apply();
            }*/
        }
        remap_check.apply();
        if(hdr.meta.complete == 1) hdr.meta.setInvalid();
    }
}