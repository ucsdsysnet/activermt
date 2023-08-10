control SwitchIngress(
        inout header_t hdr,
        inout metadata_t meta,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    // <control-def>
    action set_ifid(bit<32> ifid) {
        meta.ifid = ifid;
        // Set the destination port to an invalid value
        ig_tm_md.ucast_egress_port = 9w0x1ff;
    }

    table  ing_port {
        key = {
            ig_intr_md.ingress_port  : exact;
            hdr.vlan_tag.isValid()   : exact;
            hdr.vlan_tag.vid     : exact;
        }

        actions = {
            set_ifid;
        }

        size = 1024;
    }

    action set_src_ifid_md(ReplicationId_t rid, bit<9> yid, bit<16> brid, bit<13> hash1, bit<13> hash2) {
        ig_tm_md.rid = rid;
        ig_tm_md.level2_exclusion_id = yid;
        meta.brid = brid;
        ig_tm_md.level1_mcast_hash = hash1;
        ig_tm_md.level2_mcast_hash = hash2;
    }

    table  ing_src_ifid {
        key = {
            meta.ifid : exact;
        }

        actions = {
            set_src_ifid_md;
        }

        size = 1024;
    }

    action flood() {
        ig_tm_md.mcast_grp_a = meta.brid;
    }

    action l2_switch(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action route(bit<16> vrf) {
        meta.l3 = 1;
        meta.vrf = vrf;
    }

    table ing_dmac {
        key = {
            meta.brid   : exact;
            hdr.ethernet.dst_addr : exact;
        }

        actions = {
            l2_switch;
            route;
            flood;
        }

        const default_action = flood;
        size = 1024;
    }

    action mcast_route(bit<16> xid, MulticastGroupId_t mgid1, MulticastGroupId_t mgid2) {
        ig_tm_md.level1_exclusion_id = xid;
        ig_tm_md.mcast_grp_a = mgid1;
        ig_tm_md.mcast_grp_b = mgid2;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ing_ipv4_mcast {
        key = {
            meta.vrf   : exact;
            hdr.ipv4.src_addr : ternary;
            hdr.ipv4.dst_addr : ternary;
        }

        actions = {
            mcast_route;
        }

        size = 1024;
    }
    // </control-def>

    apply {
        // <control-flow>
        ing_port.apply();
        ing_src_ifid.apply();
        ing_dmac.apply();
        if (meta.l3 == 1) {
            ing_ipv4_mcast.apply();
        }
        // </control-flow>

        // No need for egress processing, skip it and use empty controls for egress.
        ig_tm_md.bypass_egress = 1w1;
    }
}