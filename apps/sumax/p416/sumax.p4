#include <core.p4>
#include <tna.p4>

#define ALPHA           1
#define DELAY_THRESH_Q0 1
#define DELAY_THRESH_Q1 10
#define DELAY_THRESH_Q2 100
#define REGMAX          0x1FFFFFFF

typedef bit<48> mac_addr_t;

enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    ARP  = 0x0806,
    AP4  = 0x83B2
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header bridged_metadata_h {
    bit<32> ingress_tstamp;
    bit<32> egress_tstamp;
}

struct ig_metadata_t {}

struct eg_metadata_t {
    bit<16> addr;
    bit<32> key;
    bit<32> oldkey;
    bit<32> omega;
    bit<32> buf;
    bit<32> buf2;
    bit<32> tlast;
    bit<32> qdelay;
}

struct ingress_headers_t {
    bridged_metadata_h                          meta;
    ethernet_h                                  ethernet;
}

struct egress_headers_t {
    bridged_metadata_h                          meta;
    ethernet_h                                  ethernet;
}

parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
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
    action send(PortId_t port, mac_addr_t mac) {
        ig_tm_md.ucast_egress_port = port;
        hdr.ethernet.dst_addr = mac;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table mac_host {
        key = {
            hdr.ethernet.src_addr   : exact;
        }
        actions = {
            send;
            drop;
        }
    }

    apply {
        if(hdr.ethernet.isValid()) mac_host.apply();
        hdr.meta.ingress_tstamp = (bit<32>)ig_prsr_md.global_tstamp[31:0];
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    apply {
        pkt.emit(hdr);
    }
}

parser EgressParser(
    packet_in                       pkt,
    out egress_headers_t            hdr,
    out eg_metadata_t               meta,
    
    out egress_intrinsic_metadata_t eg_intr_md
) {
    state start {
        pkt.extract(eg_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        meta.key = (bit<32>)hdr.ethernet.dst_addr[31:0];
        meta.omega = REGMAX;
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
    Hash<bit<16>>(HashAlgorithm_t.CRC16) crc16;

    Register<bit<32>, bit<32>>(32w65536) stage_0_key;
    Register<bit<32>, bit<32>>(32w65536) flow_size;
    Register<bit<32>, bit<32>>(32w65536) last_time;
    Register<bit<32>, bit<32>>(32w65536) interarrival_time;
    Register<bit<32>, bit<32>>(32w65536) delay_0;
    Register<bit<32>, bit<32>>(32w65536) delay_1;
    Register<bit<32>, bit<32>>(32w65536) delay_2;
    Register<bit<32>, bit<32>>(32w65536) delay_3;

    RegisterAction<bit<32>, bit<32>, bit<32>>(stage_0_key) key_check = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            if(obj == 0) {
                obj = meta.key;
            }
            rv = obj;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(flow_size) update_flow_size = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            if(obj < meta.buf) {
                obj = obj + ALPHA;
            } else if(obj < meta.omega) {
                obj = meta.omega;
            }
            rv = obj;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(last_time) update_last_time = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            rv = obj;
            if(obj < meta.buf2) {
                obj = meta.buf2;
            }
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(interarrival_time) update_interarrival_time = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            rv = obj;
            if(obj < meta.buf2) {
                obj = meta.buf2;
            }
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(delay_0) update_delay_0 = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            if(obj < meta.buf) {
                obj = obj + ALPHA;
            } else if(obj < meta.omega) {
                obj = meta.omega;
            }
            rv = obj;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(delay_1) update_delay_1 = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            if(obj < meta.buf) {
                obj = obj + ALPHA;
            } else if(obj < meta.omega) {
                obj = meta.omega;
            }
            rv = obj;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(delay_2) update_delay_2 = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            if(obj < meta.buf) {
                obj = obj + ALPHA;
            } else if(obj < meta.omega) {
                obj = meta.omega;
            }
            rv = obj;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<32>>(delay_3) update_delay_3 = {
        void apply(inout bit<32> obj, out bit<32> rv) {
            if(obj < meta.buf) {
                obj = obj + ALPHA;
            } else if(obj < meta.omega) {
                obj = meta.omega;
            }
            rv = obj;
        }
    };

    action hash_flow() {
        meta.addr = crc16.get({
            hdr.ethernet.src_addr,
            hdr.ethernet.dst_addr
        });
    }

    action insert_stage_0_key() {
        meta.oldkey = key_check.execute((bit<32>)meta.addr);
    }

    action prepare_flow_size() {
        meta.buf = meta.omega - ALPHA;
    }

    action prepare_tlast() {
        meta.buf2 = hdr.meta.ingress_tstamp;
    }

    action update_stat_flowsize() {
        update_flow_size.execute((bit<32>)meta.addr);
    }

    action update_stat_tlast() {
        meta.tlast = update_last_time.execute((bit<32>)meta.addr);
    }

    action compute_interval() {
        meta.buf2 = hdr.meta.ingress_tstamp - meta.tlast;
    }

    action update_stat_interarrival() {
        update_interarrival_time.execute((bit<32>)meta.addr);
    }

    action compute_queuing_delay() {
        meta.qdelay = hdr.meta.egress_tstamp - hdr.meta.ingress_tstamp;
    }

    action update_stat_delay_0() {
        meta.buf = DELAY_THRESH_Q0;
        update_delay_0.execute((bit<32>)meta.addr);
    }

    action update_stat_delay_1() {
        meta.buf = DELAY_THRESH_Q1;
        update_delay_1.execute((bit<32>)meta.addr);
    }

    action update_stat_delay_2() {
        meta.buf = DELAY_THRESH_Q2;
        update_delay_2.execute((bit<32>)meta.addr);
    }

    action update_stat_delay_3() {
        meta.buf = REGMAX;
        update_delay_3.execute((bit<32>)meta.addr);
    }

    apply {
        hdr.meta.egress_tstamp = (bit<32>)eg_prsr_md.global_tstamp[31:0];
        compute_queuing_delay();
        hash_flow();
        insert_stage_0_key();
        if(meta.oldkey == meta.key) {
            prepare_flow_size();
            prepare_tlast();
            update_stat_flowsize();
            update_stat_tlast();
            if(meta.tlast == 0) meta.buf2 = 0;
            else compute_interval();
            update_stat_interarrival();
            meta.omega = REGMAX;
            update_stat_delay_0();
            update_stat_delay_1();
            update_stat_delay_2();
            update_stat_delay_3();
        }
    }
}

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    apply {
        pkt.emit(hdr);
    }
}

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;