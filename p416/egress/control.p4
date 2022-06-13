control Egress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    

Register<bit<32>, bit<32>>(32w65536) heap_s0;

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_write_s0 = {
    void apply(inout bit<32> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_bulk_write_s0 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_10;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_read_s0 = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_count_s0 = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<32>, bit<32>>(32w65536) heap_s1;

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_write_s1 = {
    void apply(inout bit<32> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_bulk_write_s1 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_11;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_read_s1 = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_count_s1 = {
    void apply(inout bit<32> value, out bit<32> rv) {
        rv = value;
        value = value + 1;
    }
};

    

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s0;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s0) crc_16_s0;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s1;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s1) crc_16_s1;

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

    action complete() {
    hdr.meta.complete = 1;
}

action uncomplete() {
    hdr.meta.complete = 0;
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

action mar_add_mbr2() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr2;
}

action mbr_add_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.meta.mbr2;
}

action mar_mbr_add_mbr2() {
    hdr.meta.mar = hdr.meta.mbr + hdr.meta.mbr2;
}

Hash<bit<16>>(HashAlgorithm_t.CRC16) crc16;

action hash_5_tuple() {
    hdr.meta.mbr = (bit<32>)crc16.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4,
        hdr.meta.mbr
    });
}

action load_salt() {
    hdr.meta.mbr = CONST_SALT;
}
action mar_load_d0() {
    hdr.meta.mar = hdr.data.data_0;
}

action d0_load_mar() {
    hdr.data.data_0 = hdr.meta.mar;
}

/*action mar_add_d0() {
    hdr.meta.mar = hdr.meta.mar + hdr.data.data_0;
}*/

/*action bit_and_mar_d0() {
    hdr.meta.mar = hdr.meta.mar & hdr.data.data_0;
}*/

/*action mar_equals_d0() {
    hdr.meta.mar = hdr.meta.mar ^ hdr.data.data_0;
}*/
action mar_load_d1() {
    hdr.meta.mar = hdr.data.data_1;
}

action d1_load_mar() {
    hdr.data.data_1 = hdr.meta.mar;
}

/*action mar_add_d1() {
    hdr.meta.mar = hdr.meta.mar + hdr.data.data_1;
}*/

/*action bit_and_mar_d1() {
    hdr.meta.mar = hdr.meta.mar & hdr.data.data_1;
}*/

/*action mar_equals_d1() {
    hdr.meta.mar = hdr.meta.mar ^ hdr.data.data_1;
}*/
action mar_load_d2() {
    hdr.meta.mar = hdr.data.data_2;
}

action d2_load_mar() {
    hdr.data.data_2 = hdr.meta.mar;
}

/*action mar_add_d2() {
    hdr.meta.mar = hdr.meta.mar + hdr.data.data_2;
}*/

/*action bit_and_mar_d2() {
    hdr.meta.mar = hdr.meta.mar & hdr.data.data_2;
}*/

/*action mar_equals_d2() {
    hdr.meta.mar = hdr.meta.mar ^ hdr.data.data_2;
}*/
action mar_load_d3() {
    hdr.meta.mar = hdr.data.data_3;
}

action d3_load_mar() {
    hdr.data.data_3 = hdr.meta.mar;
}

/*action mar_add_d3() {
    hdr.meta.mar = hdr.meta.mar + hdr.data.data_3;
}*/

/*action bit_and_mar_d3() {
    hdr.meta.mar = hdr.meta.mar & hdr.data.data_3;
}*/

/*action mar_equals_d3() {
    hdr.meta.mar = hdr.meta.mar ^ hdr.data.data_3;
}*/
action mar_load_d4() {
    hdr.meta.mar = hdr.data.data_4;
}

action d4_load_mar() {
    hdr.data.data_4 = hdr.meta.mar;
}

/*action mar_add_d4() {
    hdr.meta.mar = hdr.meta.mar + hdr.data.data_4;
}*/

/*action bit_and_mar_d4() {
    hdr.meta.mar = hdr.meta.mar & hdr.data.data_4;
}*/

/*action mar_equals_d4() {
    hdr.meta.mar = hdr.meta.mar ^ hdr.data.data_4;
}*/
action mbr_load_d0() {
    hdr.meta.mbr = hdr.data.data_0;
}

action d0_load_mbr() {
    hdr.data.data_0 = hdr.meta.mbr;
}

/*action mbr_add_d0() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.data.data_0;
}*/

/*action bit_and_mbr_d0() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.data.data_0;
}*/

/*action mbr_equals_d0() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_0;
}*/
action mbr_load_d1() {
    hdr.meta.mbr = hdr.data.data_1;
}

action d1_load_mbr() {
    hdr.data.data_1 = hdr.meta.mbr;
}

/*action mbr_add_d1() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.data.data_1;
}*/

/*action bit_and_mbr_d1() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.data.data_1;
}*/

/*action mbr_equals_d1() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_1;
}*/
action mbr_load_d2() {
    hdr.meta.mbr = hdr.data.data_2;
}

action d2_load_mbr() {
    hdr.data.data_2 = hdr.meta.mbr;
}

/*action mbr_add_d2() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.data.data_2;
}*/

/*action bit_and_mbr_d2() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.data.data_2;
}*/

/*action mbr_equals_d2() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_2;
}*/
action mbr_load_d3() {
    hdr.meta.mbr = hdr.data.data_3;
}

action d3_load_mbr() {
    hdr.data.data_3 = hdr.meta.mbr;
}

/*action mbr_add_d3() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.data.data_3;
}*/

/*action bit_and_mbr_d3() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.data.data_3;
}*/

/*action mbr_equals_d3() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_3;
}*/
action mbr_load_d4() {
    hdr.meta.mbr = hdr.data.data_4;
}

action d4_load_mbr() {
    hdr.data.data_4 = hdr.meta.mbr;
}

/*action mbr_add_d4() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.data.data_4;
}*/

/*action bit_and_mbr_d4() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.data.data_4;
}*/

/*action mbr_equals_d4() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_4;
}*/
action mbr2_load_d0() {
    hdr.meta.mbr2 = hdr.data.data_0;
}

action d0_load_mbr2() {
    hdr.data.data_0 = hdr.meta.mbr2;
}

/*action mbr2_add_d0() {
    hdr.meta.mbr2 = hdr.meta.mbr2 + hdr.data.data_0;
}*/

/*action bit_and_mbr2_d0() {
    hdr.meta.mbr2 = hdr.meta.mbr2 & hdr.data.data_0;
}*/

/*action mbr2_equals_d0() {
    hdr.meta.mbr2 = hdr.meta.mbr2 ^ hdr.data.data_0;
}*/
action mbr2_load_d1() {
    hdr.meta.mbr2 = hdr.data.data_1;
}

action d1_load_mbr2() {
    hdr.data.data_1 = hdr.meta.mbr2;
}

/*action mbr2_add_d1() {
    hdr.meta.mbr2 = hdr.meta.mbr2 + hdr.data.data_1;
}*/

/*action bit_and_mbr2_d1() {
    hdr.meta.mbr2 = hdr.meta.mbr2 & hdr.data.data_1;
}*/

/*action mbr2_equals_d1() {
    hdr.meta.mbr2 = hdr.meta.mbr2 ^ hdr.data.data_1;
}*/
action mbr2_load_d2() {
    hdr.meta.mbr2 = hdr.data.data_2;
}

action d2_load_mbr2() {
    hdr.data.data_2 = hdr.meta.mbr2;
}

/*action mbr2_add_d2() {
    hdr.meta.mbr2 = hdr.meta.mbr2 + hdr.data.data_2;
}*/

/*action bit_and_mbr2_d2() {
    hdr.meta.mbr2 = hdr.meta.mbr2 & hdr.data.data_2;
}*/

/*action mbr2_equals_d2() {
    hdr.meta.mbr2 = hdr.meta.mbr2 ^ hdr.data.data_2;
}*/
action mbr2_load_d3() {
    hdr.meta.mbr2 = hdr.data.data_3;
}

action d3_load_mbr2() {
    hdr.data.data_3 = hdr.meta.mbr2;
}

/*action mbr2_add_d3() {
    hdr.meta.mbr2 = hdr.meta.mbr2 + hdr.data.data_3;
}*/

/*action bit_and_mbr2_d3() {
    hdr.meta.mbr2 = hdr.meta.mbr2 & hdr.data.data_3;
}*/

/*action mbr2_equals_d3() {
    hdr.meta.mbr2 = hdr.meta.mbr2 ^ hdr.data.data_3;
}*/
action mbr2_load_d4() {
    hdr.meta.mbr2 = hdr.data.data_4;
}

action d4_load_mbr2() {
    hdr.data.data_4 = hdr.meta.mbr2;
}

/*action mbr2_add_d4() {
    hdr.meta.mbr2 = hdr.meta.mbr2 + hdr.data.data_4;
}*/

/*action bit_and_mbr2_d4() {
    hdr.meta.mbr2 = hdr.meta.mbr2 & hdr.data.data_4;
}*/

/*action mbr2_equals_d4() {
    hdr.meta.mbr2 = hdr.meta.mbr2 ^ hdr.data.data_4;
}*/
action jump_s0() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s0() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[0].goto);
}

action memory_read_s0() {
    hdr.meta.mbr = heap_read_s0.execute((bit<32>)hdr.meta.mar);
}

action memory_bulk_read_s0() {
    hdr.bulk_data.data_10 = heap_read_s0.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}

action memory_write_s0() {
    heap_write_s0.execute((bit<32>)hdr.meta.mar);
}

action memory_bulk_write_s0() {
    heap_bulk_write_s0.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s0() {
    hdr.meta.mbr = heap_count_s0.execute(hdr.meta.mar);
}

action hash_s0() {
    //hdr.meta.mar = (bit<32>)crc_16_s0.get({hdr.meta.mbr});
}action jump_s1() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s1() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[1].goto);
}

action memory_read_s1() {
    hdr.meta.mbr = heap_read_s1.execute((bit<32>)hdr.meta.mar);
}

action memory_bulk_read_s1() {
    hdr.bulk_data.data_11 = heap_read_s1.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}

action memory_write_s1() {
    heap_write_s1.execute((bit<32>)hdr.meta.mar);
}

action memory_bulk_write_s1() {
    heap_bulk_write_s1.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s1() {
    hdr.meta.mbr = heap_count_s1.execute(hdr.meta.mar);
}

action hash_s1() {
    //hdr.meta.mar = (bit<32>)crc_16_s1.get({hdr.meta.mbr});
}

    // GENERATED: TABLES

    

table instruction_0 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[0].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        //hdr.meta.zero                           : exact;
        hdr.meta.mbr[19:0]                      : range;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        complete;
uncomplete;
copy_mbr2_mbr1;
copy_mbr1_mbr2;
mark_packet;
memfault;
min_mbr1_mbr2;
min_mbr2_mbr1;
mbr1_equals_mbr2;
copy_mar_mbr;
copy_mbr_mar;
bit_and_mar_mbr;
mar_add_mbr;
mar_add_mbr2;
mbr_add_mbr2;
mar_mbr_add_mbr2;
hash_5_tuple;
load_salt;
mar_load_d0;
d0_load_mar;
mar_load_d1;
d1_load_mar;
mar_load_d2;
d2_load_mar;
mar_load_d3;
d3_load_mar;
mar_load_d4;
d4_load_mar;
mbr_load_d0;
d0_load_mbr;
mbr_load_d1;
d1_load_mbr;
mbr_load_d2;
d2_load_mbr;
mbr_load_d3;
d3_load_mbr;
mbr_load_d4;
d4_load_mbr;
mbr2_load_d0;
d0_load_mbr2;
mbr2_load_d1;
d1_load_mbr2;
mbr2_load_d2;
d2_load_mbr2;
mbr2_load_d3;
d3_load_mbr2;
mbr2_load_d4;
d4_load_mbr2;
jump_s0;
attempt_rejoin_s0;
memory_read_s0;
memory_bulk_read_s0;
memory_write_s0;
memory_bulk_write_s0;
memory_count_s0;
hash_s0;
    }
    size = 512;
}

table instruction_1 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[1].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        //hdr.meta.zero                           : exact;
        hdr.meta.mbr[19:0]                      : range;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        complete;
uncomplete;
copy_mbr2_mbr1;
copy_mbr1_mbr2;
mark_packet;
memfault;
min_mbr1_mbr2;
min_mbr2_mbr1;
mbr1_equals_mbr2;
copy_mar_mbr;
copy_mbr_mar;
bit_and_mar_mbr;
mar_add_mbr;
mar_add_mbr2;
mbr_add_mbr2;
mar_mbr_add_mbr2;
hash_5_tuple;
load_salt;
mar_load_d0;
d0_load_mar;
mar_load_d1;
d1_load_mar;
mar_load_d2;
d2_load_mar;
mar_load_d3;
d3_load_mar;
mar_load_d4;
d4_load_mar;
mbr_load_d0;
d0_load_mbr;
mbr_load_d1;
d1_load_mbr;
mbr_load_d2;
d2_load_mbr;
mbr_load_d3;
d3_load_mbr;
mbr_load_d4;
d4_load_mbr;
mbr2_load_d0;
d0_load_mbr2;
mbr2_load_d1;
d1_load_mbr2;
mbr2_load_d2;
d2_load_mbr2;
mbr2_load_d3;
d3_load_mbr2;
mbr2_load_d4;
d4_load_mbr2;
jump_s1;
attempt_rejoin_s1;
memory_read_s1;
memory_bulk_read_s1;
memory_write_s1;
memory_bulk_write_s1;
memory_count_s1;
hash_s1;
    }
    size = 512;
}

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
        if(hdr.instr[0].isValid()) { instruction_0.apply(); hdr.instr[0].setInvalid(); }
		if(hdr.instr[1].isValid()) { instruction_1.apply(); hdr.instr[1].setInvalid(); }
        activep4_stats.count((bit<32>)hdr.ih.fid);
        recirculation.apply();
        hdr.meta.setInvalid();
    }
}