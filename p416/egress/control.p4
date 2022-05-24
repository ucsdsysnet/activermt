control Egress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    

Register<bit<16>, bit<32>>(32w65536) heap_s0;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s0) heap_write_s0 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s0) heap_read_s0 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s0) heap_count_s0 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s1;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s1) heap_write_s1 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s1) heap_read_s1 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s1) heap_count_s1 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s2;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s2) heap_write_s2 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s2) heap_read_s2 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s2) heap_count_s2 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s3;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s3) heap_write_s3 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s3) heap_read_s3 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s3) heap_count_s3 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s4;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s4) heap_write_s4 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s4) heap_read_s4 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s4) heap_count_s4 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s5;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s5) heap_write_s5 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s5) heap_read_s5 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s5) heap_count_s5 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s6;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s6) heap_write_s6 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s6) heap_read_s6 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s6) heap_count_s6 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s7;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s7) heap_write_s7 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s7) heap_read_s7 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s7) heap_count_s7 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s8;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s8) heap_write_s8 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s8) heap_read_s8 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s8) heap_count_s8 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
        value = value + 1;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s9;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s9) heap_write_s9 = {
    void apply(inout bit<16> value) {
        value = hdr.meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s9) heap_read_s9 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s9) heap_count_s9 = {
    void apply(inout bit<16> value, out bit<16> rv) {
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

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s2;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s2) crc_16_s2;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s3;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s3) crc_16_s3;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s4;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s4) crc_16_s4;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s5;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s5) crc_16_s5;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s6;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s6) crc_16_s6;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s7;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s7) crc_16_s7;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s8;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s8) crc_16_s8;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = false,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s9;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s9) crc_16_s9;

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

    action mar_add_mbr2() {
        hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr2;
    }

    action mbr_add_mbr2() {
        hdr.meta.mbr = hdr.meta.mbr + hdr.meta.mbr2;
    }

    action mar_mbr_add_mbr2() {
        hdr.meta.mar = hdr.meta.mbr + hdr.meta.mbr2;
    }

    action copy_acc_mbr() {
        hdr.ih.acc = hdr.meta.mbr;
    }

    Hash<bit<16>>(HashAlgorithm_t.CRC16) crc16;

    action hash_5_tuple() {
        hdr.meta.mbr = crc16.get({
            hdr.meta.ipv4_src,
            hdr.meta.ipv4_dst,
            hdr.meta.ipv4_protocol,
            hdr.meta.l4_src,
            hdr.meta.l4_dst,
            hdr.meta.mbr
        });
    }

    action load_salt() {
        hdr.meta.mbr = CONST_SALT;
    }

    // GENERATED: ACTIONS

    action mar_load_s0() {
    hdr.meta.mar = hdr.instr[0].arg;
}

action mbr1_load_s0() {
    hdr.meta.mbr = hdr.instr[0].arg;
}

action mbr2_load_s0() {
    hdr.meta.mbr2 = hdr.instr[0].arg;
}

action mbr_add_s0() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[0].arg;
}

action mar_add_s0() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[0].arg;
}

action jump_s0() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s0() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[0].goto);
}

action bit_and_mbr_s0() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[0].arg;
}

action bit_and_mar_s0() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[0].arg;
}

action mbr_equals_arg_s0() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[0].arg;
}

action memory_read_s0() {
    hdr.meta.mbr = heap_read_s0.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s0() {
    heap_write_s0.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s0() {
    hdr.meta.mbr = heap_count_s0.execute((bit<32>)hdr.meta.mar);
}

action hash_s0() {
    hdr.meta.mar = crc_16_s0.get({hdr.meta.mbr});
}action mar_load_s1() {
    hdr.meta.mar = hdr.instr[1].arg;
}

action mbr1_load_s1() {
    hdr.meta.mbr = hdr.instr[1].arg;
}

action mbr2_load_s1() {
    hdr.meta.mbr2 = hdr.instr[1].arg;
}

action mbr_add_s1() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[1].arg;
}

action mar_add_s1() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[1].arg;
}

action jump_s1() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s1() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[1].goto);
}

action bit_and_mbr_s1() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[1].arg;
}

action bit_and_mar_s1() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[1].arg;
}

action mbr_equals_arg_s1() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[1].arg;
}

action memory_read_s1() {
    hdr.meta.mbr = heap_read_s1.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s1() {
    heap_write_s1.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s1() {
    hdr.meta.mbr = heap_count_s1.execute((bit<32>)hdr.meta.mar);
}

action hash_s1() {
    hdr.meta.mar = crc_16_s1.get({hdr.meta.mbr});
}action mar_load_s2() {
    hdr.meta.mar = hdr.instr[2].arg;
}

action mbr1_load_s2() {
    hdr.meta.mbr = hdr.instr[2].arg;
}

action mbr2_load_s2() {
    hdr.meta.mbr2 = hdr.instr[2].arg;
}

action mbr_add_s2() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[2].arg;
}

action mar_add_s2() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[2].arg;
}

action jump_s2() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s2() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[2].goto);
}

action bit_and_mbr_s2() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[2].arg;
}

action bit_and_mar_s2() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[2].arg;
}

action mbr_equals_arg_s2() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[2].arg;
}

action memory_read_s2() {
    hdr.meta.mbr = heap_read_s2.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s2() {
    heap_write_s2.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s2() {
    hdr.meta.mbr = heap_count_s2.execute((bit<32>)hdr.meta.mar);
}

action hash_s2() {
    hdr.meta.mar = crc_16_s2.get({hdr.meta.mbr});
}action mar_load_s3() {
    hdr.meta.mar = hdr.instr[3].arg;
}

action mbr1_load_s3() {
    hdr.meta.mbr = hdr.instr[3].arg;
}

action mbr2_load_s3() {
    hdr.meta.mbr2 = hdr.instr[3].arg;
}

action mbr_add_s3() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[3].arg;
}

action mar_add_s3() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[3].arg;
}

action jump_s3() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s3() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[3].goto);
}

action bit_and_mbr_s3() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[3].arg;
}

action bit_and_mar_s3() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[3].arg;
}

action mbr_equals_arg_s3() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[3].arg;
}

action memory_read_s3() {
    hdr.meta.mbr = heap_read_s3.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s3() {
    heap_write_s3.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s3() {
    hdr.meta.mbr = heap_count_s3.execute((bit<32>)hdr.meta.mar);
}

action hash_s3() {
    hdr.meta.mar = crc_16_s3.get({hdr.meta.mbr});
}action mar_load_s4() {
    hdr.meta.mar = hdr.instr[4].arg;
}

action mbr1_load_s4() {
    hdr.meta.mbr = hdr.instr[4].arg;
}

action mbr2_load_s4() {
    hdr.meta.mbr2 = hdr.instr[4].arg;
}

action mbr_add_s4() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[4].arg;
}

action mar_add_s4() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[4].arg;
}

action jump_s4() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s4() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[4].goto);
}

action bit_and_mbr_s4() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[4].arg;
}

action bit_and_mar_s4() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[4].arg;
}

action mbr_equals_arg_s4() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[4].arg;
}

action memory_read_s4() {
    hdr.meta.mbr = heap_read_s4.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s4() {
    heap_write_s4.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s4() {
    hdr.meta.mbr = heap_count_s4.execute((bit<32>)hdr.meta.mar);
}

action hash_s4() {
    hdr.meta.mar = crc_16_s4.get({hdr.meta.mbr});
}action mar_load_s5() {
    hdr.meta.mar = hdr.instr[5].arg;
}

action mbr1_load_s5() {
    hdr.meta.mbr = hdr.instr[5].arg;
}

action mbr2_load_s5() {
    hdr.meta.mbr2 = hdr.instr[5].arg;
}

action mbr_add_s5() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[5].arg;
}

action mar_add_s5() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[5].arg;
}

action jump_s5() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s5() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[5].goto);
}

action bit_and_mbr_s5() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[5].arg;
}

action bit_and_mar_s5() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[5].arg;
}

action mbr_equals_arg_s5() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[5].arg;
}

action memory_read_s5() {
    hdr.meta.mbr = heap_read_s5.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s5() {
    heap_write_s5.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s5() {
    hdr.meta.mbr = heap_count_s5.execute((bit<32>)hdr.meta.mar);
}

action hash_s5() {
    hdr.meta.mar = crc_16_s5.get({hdr.meta.mbr});
}action mar_load_s6() {
    hdr.meta.mar = hdr.instr[6].arg;
}

action mbr1_load_s6() {
    hdr.meta.mbr = hdr.instr[6].arg;
}

action mbr2_load_s6() {
    hdr.meta.mbr2 = hdr.instr[6].arg;
}

action mbr_add_s6() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[6].arg;
}

action mar_add_s6() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[6].arg;
}

action jump_s6() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s6() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[6].goto);
}

action bit_and_mbr_s6() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[6].arg;
}

action bit_and_mar_s6() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[6].arg;
}

action mbr_equals_arg_s6() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[6].arg;
}

action memory_read_s6() {
    hdr.meta.mbr = heap_read_s6.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s6() {
    heap_write_s6.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s6() {
    hdr.meta.mbr = heap_count_s6.execute((bit<32>)hdr.meta.mar);
}

action hash_s6() {
    hdr.meta.mar = crc_16_s6.get({hdr.meta.mbr});
}action mar_load_s7() {
    hdr.meta.mar = hdr.instr[7].arg;
}

action mbr1_load_s7() {
    hdr.meta.mbr = hdr.instr[7].arg;
}

action mbr2_load_s7() {
    hdr.meta.mbr2 = hdr.instr[7].arg;
}

action mbr_add_s7() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[7].arg;
}

action mar_add_s7() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[7].arg;
}

action jump_s7() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s7() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[7].goto);
}

action bit_and_mbr_s7() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[7].arg;
}

action bit_and_mar_s7() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[7].arg;
}

action mbr_equals_arg_s7() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[7].arg;
}

action memory_read_s7() {
    hdr.meta.mbr = heap_read_s7.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s7() {
    heap_write_s7.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s7() {
    hdr.meta.mbr = heap_count_s7.execute((bit<32>)hdr.meta.mar);
}

action hash_s7() {
    hdr.meta.mar = crc_16_s7.get({hdr.meta.mbr});
}action mar_load_s8() {
    hdr.meta.mar = hdr.instr[8].arg;
}

action mbr1_load_s8() {
    hdr.meta.mbr = hdr.instr[8].arg;
}

action mbr2_load_s8() {
    hdr.meta.mbr2 = hdr.instr[8].arg;
}

action mbr_add_s8() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[8].arg;
}

action mar_add_s8() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[8].arg;
}

action jump_s8() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s8() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[8].goto);
}

action bit_and_mbr_s8() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[8].arg;
}

action bit_and_mar_s8() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[8].arg;
}

action mbr_equals_arg_s8() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[8].arg;
}

action memory_read_s8() {
    hdr.meta.mbr = heap_read_s8.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s8() {
    heap_write_s8.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s8() {
    hdr.meta.mbr = heap_count_s8.execute((bit<32>)hdr.meta.mar);
}

action hash_s8() {
    hdr.meta.mar = crc_16_s8.get({hdr.meta.mbr});
}action mar_load_s9() {
    hdr.meta.mar = hdr.instr[9].arg;
}

action mbr1_load_s9() {
    hdr.meta.mbr = hdr.instr[9].arg;
}

action mbr2_load_s9() {
    hdr.meta.mbr2 = hdr.instr[9].arg;
}

action mbr_add_s9() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[9].arg;
}

action mar_add_s9() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[9].arg;
}

action jump_s9() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s9() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[9].goto);
}

action bit_and_mbr_s9() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[9].arg;
}

action bit_and_mar_s9() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[9].arg;
}

action mbr_equals_arg_s9() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[9].arg;
}

action memory_read_s9() {
    hdr.meta.mbr = heap_read_s9.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s9() {
    heap_write_s9.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s9() {
    hdr.meta.mbr = heap_count_s9.execute((bit<32>)hdr.meta.mar);
}

action hash_s9() {
    hdr.meta.mar = crc_16_s9.get({hdr.meta.mbr});
}

    // GENERATED: TABLES

    

table instruction_0 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[0].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s0;
mbr1_load_s0;
mbr2_load_s0;
mbr_add_s0;
mar_add_s0;
jump_s0;
attempt_rejoin_s0;
bit_and_mbr_s0;
bit_and_mar_s0;
mbr_equals_arg_s0;
memory_read_s0;
memory_write_s0;
memory_count_s0;
hash_s0;
    }
}

table instruction_1 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[1].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s1;
mbr1_load_s1;
mbr2_load_s1;
mbr_add_s1;
mar_add_s1;
jump_s1;
attempt_rejoin_s1;
bit_and_mbr_s1;
bit_and_mar_s1;
mbr_equals_arg_s1;
memory_read_s1;
memory_write_s1;
memory_count_s1;
hash_s1;
    }
}

table instruction_2 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[2].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s2;
mbr1_load_s2;
mbr2_load_s2;
mbr_add_s2;
mar_add_s2;
jump_s2;
attempt_rejoin_s2;
bit_and_mbr_s2;
bit_and_mar_s2;
mbr_equals_arg_s2;
memory_read_s2;
memory_write_s2;
memory_count_s2;
hash_s2;
    }
}

table instruction_3 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[3].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s3;
mbr1_load_s3;
mbr2_load_s3;
mbr_add_s3;
mar_add_s3;
jump_s3;
attempt_rejoin_s3;
bit_and_mbr_s3;
bit_and_mar_s3;
mbr_equals_arg_s3;
memory_read_s3;
memory_write_s3;
memory_count_s3;
hash_s3;
    }
}

table instruction_4 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[4].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s4;
mbr1_load_s4;
mbr2_load_s4;
mbr_add_s4;
mar_add_s4;
jump_s4;
attempt_rejoin_s4;
bit_and_mbr_s4;
bit_and_mar_s4;
mbr_equals_arg_s4;
memory_read_s4;
memory_write_s4;
memory_count_s4;
hash_s4;
    }
}

table instruction_5 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[5].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s5;
mbr1_load_s5;
mbr2_load_s5;
mbr_add_s5;
mar_add_s5;
jump_s5;
attempt_rejoin_s5;
bit_and_mbr_s5;
bit_and_mar_s5;
mbr_equals_arg_s5;
memory_read_s5;
memory_write_s5;
memory_count_s5;
hash_s5;
    }
}

table instruction_6 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[6].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s6;
mbr1_load_s6;
mbr2_load_s6;
mbr_add_s6;
mar_add_s6;
jump_s6;
attempt_rejoin_s6;
bit_and_mbr_s6;
bit_and_mar_s6;
mbr_equals_arg_s6;
memory_read_s6;
memory_write_s6;
memory_count_s6;
hash_s6;
    }
}

table instruction_7 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[7].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s7;
mbr1_load_s7;
mbr2_load_s7;
mbr_add_s7;
mar_add_s7;
jump_s7;
attempt_rejoin_s7;
bit_and_mbr_s7;
bit_and_mar_s7;
mbr_equals_arg_s7;
memory_read_s7;
memory_write_s7;
memory_count_s7;
hash_s7;
    }
}

table instruction_8 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[8].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s8;
mbr1_load_s8;
mbr2_load_s8;
mbr_add_s8;
mar_add_s8;
jump_s8;
attempt_rejoin_s8;
bit_and_mbr_s8;
bit_and_mar_s8;
mbr_equals_arg_s8;
memory_read_s8;
memory_write_s8;
memory_count_s8;
hash_s8;
    }
}

table instruction_9 {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[9].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        complete;
        uncomplete;
        acc1_load;
        acc2_load;
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
        copy_acc_mbr;
        hash_5_tuple;
        load_salt;
        mar_load_s9;
mbr1_load_s9;
mbr2_load_s9;
mbr_add_s9;
mar_add_s9;
jump_s9;
attempt_rejoin_s9;
bit_and_mbr_s9;
bit_and_mar_s9;
mbr_equals_arg_s9;
memory_read_s9;
memory_write_s9;
memory_count_s9;
hash_s9;
    }
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
		if(hdr.instr[2].isValid()) { instruction_2.apply(); hdr.instr[2].setInvalid(); }
		if(hdr.instr[3].isValid()) { instruction_3.apply(); hdr.instr[3].setInvalid(); }
		if(hdr.instr[4].isValid()) { instruction_4.apply(); hdr.instr[4].setInvalid(); }
		if(hdr.instr[5].isValid()) { instruction_5.apply(); hdr.instr[5].setInvalid(); }
		if(hdr.instr[6].isValid()) { instruction_6.apply(); hdr.instr[6].setInvalid(); }
		if(hdr.instr[7].isValid()) { instruction_7.apply(); hdr.instr[7].setInvalid(); }
		if(hdr.instr[8].isValid()) { instruction_8.apply(); hdr.instr[8].setInvalid(); }
		if(hdr.instr[9].isValid()) { instruction_9.apply(); hdr.instr[9].setInvalid(); }
        activep4_stats.count((bit<32>)hdr.ih.fid);
        recirculation.apply();
        hdr.meta.setInvalid();
    }
}