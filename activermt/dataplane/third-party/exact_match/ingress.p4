control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    // <control-def>
    bit<16> vrf = (bit<16>)ig_intr_md.ingress_port;
    bit<2> color;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) cntr;
    DirectMeter(MeterType_t.BYTES) meter;

    action hit(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action miss(bit<3> drop) {
        ig_dprsr_md.drop_ctl = drop; // Drop packet.
    }

    table forward {
        key = {
            hdr.ethernet.dst_addr : exact;
        }

        actions = {
            hit;
            @defaultonly miss;
        }

        const default_action = miss(0x1);
        size = 1024;
    }

    action route(mac_addr_t srcMac, mac_addr_t dstMac, PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        hdr.ethernet.dst_addr = dstMac;
        hdr.ethernet.src_addr = srcMac;
        cntr.count();
        color = (bit<2>) meter.execute();
        ig_dprsr_md.drop_ctl = 0;
    }

    action nat(ipv4_addr_t srcAddr, ipv4_addr_t dstAddr, PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        hdr.ipv4.dst_addr = dstAddr;
        hdr.ipv4.src_addr = srcAddr;
        cntr.count();
        color = (bit<2>) meter.execute();
        ig_dprsr_md.drop_ctl = 0;
    }


    table ipRoute {
        key = {
            vrf : exact;
            hdr.ipv4.dst_addr : exact;
        }

        actions = {
            route;
            nat;
        }

        size = 1024;
        counters = cntr;
        meters = meter;
    }

    action nop() {}

    table forward_timeout {
        key = {
            hdr.ethernet.dst_addr : exact;
        }

        actions = {
            hit;
	    nop;
        }

        const default_action = nop();
        size = 200000;
    }
    // </control-def>

    apply {
        // <control-flow>
        forward.apply();
        vrf = 16w0;
        ipRoute.apply();
        forward_timeout.apply();
        // </control-flow>

        // No need for egress processing, skip it and use empty controls for egress.
        ig_tm_md.bypass_egress = 1w1;
    }
}