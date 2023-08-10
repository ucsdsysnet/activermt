// Adapted from p4lang/tutorials.

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// No additional header definitions.
// No additional parser definitions.
// No additional checksum verifications.

/**
    Use pre-defined header names for Internet Protocol headers.
*/

control MyIngress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    // <control-def>

    Register<bit<BLOOM_FILTER_BIT_WIDTH>, bit<32>>(32w4096) bloom_filter_1;
    Register<bit<BLOOM_FILTER_BIT_WIDTH>, bit<32>>(32w4096) bloom_filter_2;

    RegisterAction<bit<BLOOM_FILTER_BIT_WIDTH>, bit<32>, bit<BLOOM_FILTER_BIT_WIDTH>>(bloom_filter_1) bloom_filter_1_read = {
        void apply(inout bit<BLOOM_FILTER_BIT_WIDTH> value, out bit<BLOOM_FILTER_BIT_WIDTH> rv) {
            rv = value;
        }
    };

    RegisterAction<bit<BLOOM_FILTER_BIT_WIDTH>, bit<32>, bit<BLOOM_FILTER_BIT_WIDTH>>(bloom_filter_1) bloom_filter_1_write = {
        void apply(inout bit<BLOOM_FILTER_BIT_WIDTH> value, out bit<BLOOM_FILTER_BIT_WIDTH> rv) {
            value = 1;
        }
    };

    RegisterAction<bit<BLOOM_FILTER_BIT_WIDTH>, bit<32>, bit<BLOOM_FILTER_BIT_WIDTH>>(bloom_filter_2) bloom_filter_2_read = {
        void apply(inout bit<BLOOM_FILTER_BIT_WIDTH> value, out bit<BLOOM_FILTER_BIT_WIDTH> rv) {
            rv = value;
        }
    };

    RegisterAction<bit<BLOOM_FILTER_BIT_WIDTH>, bit<32>, bit<BLOOM_FILTER_BIT_WIDTH>>(bloom_filter_2) bloom_filter_2_write = {
        void apply(inout bit<BLOOM_FILTER_BIT_WIDTH> value, out bit<BLOOM_FILTER_BIT_WIDTH> rv) {
            value = 1;
        }
    };

    // register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_1;
    // register<bit<BLOOM_FILTER_BIT_WIDTH>>(BLOOM_FILTER_ENTRIES) bloom_filter_2;

    bit<32> reg_pos_one; bit<32> reg_pos_two;
    bit<1> reg_val_one; bit<1> reg_val_two;
    bit<1> direction;

    // action drop() {
    //     // mark_to_drop(standard_metadata);
    //     ig_dprsr_md.drop_ctl = 1;
    // }

    Hash<bit<16>>(HashAlgorithm_t.CRC16) hash_1;
    Hash<bit<32>>(HashAlgorithm_t.CRC32) hash_2;

    action compute_hashes(ipv4_addr_t ipAddr1, ipv4_addr_t ipAddr2, bit<16> port1, bit<16> port2){
       //Get register position
       reg_pos_one = (bit<32>)hash_1.get({ipAddr1,
                                        ipAddr2,
                                        port1,
                                        port2,
                                        hdr.ipv4.protocol});
    //    hash(reg_pos_one, HashAlgorithm.crc16, (bit<32>)0, {ipAddr1,
    //                                                        ipAddr2,
    //                                                        port1,
    //                                                        port2,
    //                                                        hdr.ipv4.protocol},
    //                                                        (bit<32>)BLOOM_FILTER_ENTRIES);

        reg_pos_two = hash_2.get({ipAddr1,
                                ipAddr2,
                                port1,
                                port2,
                                hdr.ipv4.protocol});
    //    hash(reg_pos_two, HashAlgorithm.crc32, (bit<32>)0, {ipAddr1,
    //                                                        ipAddr2,
    //                                                        port1,
    //                                                        port2,
    //                                                        hdr.ipv4.protocol},
    //                                                        (bit<32>)BLOOM_FILTER_ENTRIES);
    }

    action ipv4_forward(mac_addr_t dstAddr, egressSpec_t port) {
        // standard_metadata.egress_spec = port;
        ig_tm_md.ucast_egress_port = port;
        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = dstAddr;
        // hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        // hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    table ipv4_lpm {
        key = {
            hdr.ipv4.dst_addr: lpm;
            // hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    action set_direction(bit<1> dir) {
        direction = dir;
    }

    table check_ports {
        key = {
            ig_intr_md.ingress_port     : exact;
            ig_tm_md.ucast_egress_port  : exact;
            // standard_metadata.ingress_port: exact;
            // standard_metadata.egress_spec: exact;
        }
        actions = {
            set_direction;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    // </control-def>

    apply {
        // <control-flow>
        if (hdr.ipv4.isValid()){
            ipv4_lpm.apply();
            if (hdr.tcp.isValid()){
                direction = 0; // default
                if (check_ports.apply().hit) {
                    // test and set the bloom filter
                    if (direction == 0) {
                        compute_hashes(hdr.ipv4.src_addr, hdr.ipv4.dst_addr, hdr.tcp.src_port, hdr.tcp.dst_port);
                        // compute_hashes(hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort);
                    }
                    else {
                        compute_hashes(hdr.ipv4.dst_addr, hdr.ipv4.src_addr, hdr.tcp.dst_port, hdr.tcp.src_port);
                        // compute_hashes(hdr.ipv4.dstAddr, hdr.ipv4.srcAddr, hdr.tcp.dstPort, hdr.tcp.srcPort);
                    }
                    // Packet comes from internal network
                    if (direction == 0){
                        // If there is a syn we update the bloom filter and add the entry
                        if (hdr.tcp.flags & 0x0002 > 0){
                            bloom_filter_1_write.execute(reg_pos_one);
                            bloom_filter_2_write.execute(reg_pos_two);
                            // bloom_filter_1.write(reg_pos_one, 1);
                            // bloom_filter_2.write(reg_pos_two, 1);
                        }
                    }
                    // Packet comes from outside
                    else if (direction == 1){
                        // Read bloom filter cells to check if there are 1's
                        bloom_filter_1_read.execute(reg_pos_one);
                        bloom_filter_2_read.execute(reg_pos_two);
                        // bloom_filter_1.read(reg_val_one, reg_pos_one);
                        // bloom_filter_2.read(reg_val_two, reg_pos_two);
                        // only allow flow to pass if both entries are set
                        if (reg_val_one != 1 || reg_val_two != 1){
                            drop();
                        }
                    }
                }
            }
        }
        // </control-flow>
    }
}

// No deparser definitions.
// No pipeline definitions.