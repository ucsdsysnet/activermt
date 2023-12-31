//    Copyright 2023 Rajdeep Das, University of California San Diego.

//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at

//        http://www.apache.org/licenses/LICENSE-2.0

//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

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

    // Taken from Tofino examples.
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

    <generated-tables>

    // resource monitoring

    Random<bit<16>>() rnd;
    Register<bit<32>, bit<32>>(32w65536) pkt_count;

    RegisterAction<bit<32>, bit<32>, bit<32>>(pkt_count) counter_pkts = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            obj = obj + 1; 
            rv = obj;
        }
    };

    action update_pkt_count_ap4() {
        hdr.meta.ig_pktcount = counter_pkts.execute((bit<32>)hdr.ih.fid);
    }

    // quota enforcement

    action enable_recirculation() {
        hdr.meta.mirror_iter = MAX_RECIRCULATIONS;
    }

    table quota_recirc {
        key = {
            hdr.ih.fid          : exact;
        }
        actions = {
            enable_recirculation;
        }
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
            routeback.apply();
            if(hdr.ih.flag_reqalloc == 1) {
                ig_dprsr_md.digest_type = 1;
            }
            if(hdr.ih.flag_remapped == 1) {
                ig_dprsr_md.digest_type = 2;
            }
            allocation.apply();
            quota_recirc.apply();
            update_pkt_count_ap4();
        } else bypass_egress();
        <generated-ctrlflow>
        <generated-malloc>
        if(hdr.ipv4.isValid()) {
            ipv4_host.apply();
        }
        remap_check.apply();
        if(hdr.meta.complete == 1) hdr.meta.setInvalid();
    }
}