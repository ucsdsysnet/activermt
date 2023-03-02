control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    // <control-def>
    Alpm(number_partitions = 1024, subtrees_per_partition = 2) algo_lpm;

    bit<10> vrf;

    action hit(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action miss() {
        ig_dprsr_md.drop_ctl = 0x1; // Drop packet.
    }

    table forward {
        key = {
            vrf : exact;
            hdr.ipv4.dst_addr : lpm;
        }

        actions = {
            hit;
            miss;
        }

        const default_action = miss;
        size = 1024;
    }

    action route(mac_addr_t srcMac, mac_addr_t dstMac, PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        hdr.ethernet.dst_addr = dstMac;
        hdr.ethernet.src_addr = srcMac;
        ig_dprsr_md.drop_ctl = 0x0;
    }

    table alpm_forward {
        key = {
            vrf : exact;
            hdr.ipv4.dst_addr : lpm;
        }

        actions = {
            route;
        }

        size = 1024;
        alpm = algo_lpm;
    }
    // </control-def>

    apply {
        // <control-flow>
        vrf = 10w0;
        forward.apply();
        alpm_forward.apply();
        // </control-flow>

        // No need for egress processing, skip it and use empty controls for egress.
        ig_tm_md.bypass_egress = 1w1;
    }
}