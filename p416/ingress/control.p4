control Ingress(
    inout ingress_headers_t                          hdr,
    inout active_metadata_t                          meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    

Register<bit<16>, bit<32>>(32w65536) heap_s1;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s1) heap_write_s1 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s1) heap_read_s1 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s2;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s2) heap_write_s2 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s2) heap_read_s2 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s3;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s3) heap_write_s3 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s3) heap_read_s3 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s4;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s4) heap_write_s4 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s4) heap_read_s4 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s5;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s5) heap_write_s5 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s5) heap_read_s5 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s6;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s6) heap_write_s6 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s6) heap_read_s6 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s7;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s7) heap_write_s7 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s7) heap_read_s7 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s8;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s8) heap_write_s8 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s8) heap_read_s8 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s9;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s9) heap_write_s9 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s9) heap_read_s9 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

Register<bit<16>, bit<32>>(32w65536) heap_s10;

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s10) heap_write_s10 = {
    void apply(inout bit<16> value) {
        value = meta.mbr;
    }
};

RegisterAction<bit<16>, bit<32>, bit<16>>(heap_s10) heap_read_s10 = {
    void apply(inout bit<16> value, out bit<16> rv) {
        rv = value;
    }
};

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
#ifdef BYPASS_EGRESS
        ig_tm_md.bypass_egress = 1;
#endif
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table ipv4_host {
        key = { hdr.ipv4.dst_addr : exact; }
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

    table ipv4_lpm {
        key     = { hdr.ipv4.dst_addr : lpm; }
        actions = { send; drop; }

        default_action = send(64);
        size           = IPV4_LPM_SIZE;
    }

    // actions

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
        ig_tm_md.ucast_egress_port = (bit<9>) meta.mbr;
    }

    action complete() {
        meta.complete = 1;
    }

    action uncomplete() {
        meta.complete = 0;
    }

    action acc1_load() {
        hdr.ih.acc = meta.mbr;
    }

    action acc2_load() {
        hdr.ih.acc2 = meta.mbr;
    }

    action copy_mbr2_mbr1() {
        meta.mbr2 = meta.mbr;
    }

    action copy_mbr1_mbr2() {
        meta.mbr = meta.mbr2;
    }

    action mark_packet() {
        hdr.ih.flag_marked = 1;
    }

    action memfault() {
        hdr.ih.flag_mfault = 1;
        hdr.ih.acc = meta.mar;
        complete();
        rts();
    }

    action min_mbr1_mbr2() {
        meta.mbr = (meta.mbr <= meta.mbr2 ? meta.mbr : meta.mbr2);
    }

    action min_mbr2_mbr1() {
        meta.mbr2 = (meta.mbr2 <= meta.mbr ? meta.mbr2 : meta.mbr);
    }

    action mbr1_equals_mbr2() {
        meta.mbr = meta.mbr ^ meta.mbr2;
    }

    action copy_mar_mbr() {
        meta.mar = meta.mbr;
    }

    action copy_mbr_mar() {
        meta.mbr = meta.mar;
    }

    action bit_and_mar_mbr() {
        meta.mar = meta.mar & meta.mbr;
    }

    action mar_add_mbr() {
        meta.mar = meta.mar + meta.mbr;
    }

    action copy_acc_mbr() {
        hdr.ih.acc = meta.mbr;
    }

    // GENERATED: ACTIONS

    action mar_load_s1() {
    meta.mar = hdr.instr[0].arg;
}

action mbr1_load_s1() {
    meta.mbr = hdr.instr[0].arg;
}

action mbr2_load_s1() {
    meta.mbr2 = hdr.instr[0].arg;
}

action mbr_add_s1() {
    meta.mbr = meta.mbr + hdr.instr[0].arg;
}

action mar_add_s1() {
    meta.mar = meta.mar + hdr.instr[0].arg;
}

action jump_s1() {
    meta.disabled = 1;
    meta.pc = hdr.instr[0].goto;
}

action attempt_rejoin_s1() {
    meta.disabled = (meta.pc ^ hdr.instr[0].goto);
}

action bit_and_mbr_s1() {
    meta.mbr = meta.mbr & hdr.instr[0].arg;
}

action bit_and_mar_s1() {
    meta.mar = meta.mar & hdr.instr[0].arg;
}

action mbr_equals_arg_s1() {
    meta.mbr = meta.mbr ^ hdr.instr[0].arg;
}

action memory_read_s1() {
    meta.mbr = heap_read_s1.execute((bit<32>)meta.mar);
}

action memory_write_s1() {
    heap_write_s1.execute((bit<32>)meta.mar);
}action mar_load_s2() {
    meta.mar = hdr.instr[1].arg;
}

action mbr1_load_s2() {
    meta.mbr = hdr.instr[1].arg;
}

action mbr2_load_s2() {
    meta.mbr2 = hdr.instr[1].arg;
}

action mbr_add_s2() {
    meta.mbr = meta.mbr + hdr.instr[1].arg;
}

action mar_add_s2() {
    meta.mar = meta.mar + hdr.instr[1].arg;
}

action jump_s2() {
    meta.disabled = 1;
    meta.pc = hdr.instr[1].goto;
}

action attempt_rejoin_s2() {
    meta.disabled = (meta.pc ^ hdr.instr[1].goto);
}

action bit_and_mbr_s2() {
    meta.mbr = meta.mbr & hdr.instr[1].arg;
}

action bit_and_mar_s2() {
    meta.mar = meta.mar & hdr.instr[1].arg;
}

action mbr_equals_arg_s2() {
    meta.mbr = meta.mbr ^ hdr.instr[1].arg;
}

action memory_read_s2() {
    meta.mbr = heap_read_s2.execute((bit<32>)meta.mar);
}

action memory_write_s2() {
    heap_write_s2.execute((bit<32>)meta.mar);
}action mar_load_s3() {
    meta.mar = hdr.instr[2].arg;
}

action mbr1_load_s3() {
    meta.mbr = hdr.instr[2].arg;
}

action mbr2_load_s3() {
    meta.mbr2 = hdr.instr[2].arg;
}

action mbr_add_s3() {
    meta.mbr = meta.mbr + hdr.instr[2].arg;
}

action mar_add_s3() {
    meta.mar = meta.mar + hdr.instr[2].arg;
}

action jump_s3() {
    meta.disabled = 1;
    meta.pc = hdr.instr[2].goto;
}

action attempt_rejoin_s3() {
    meta.disabled = (meta.pc ^ hdr.instr[2].goto);
}

action bit_and_mbr_s3() {
    meta.mbr = meta.mbr & hdr.instr[2].arg;
}

action bit_and_mar_s3() {
    meta.mar = meta.mar & hdr.instr[2].arg;
}

action mbr_equals_arg_s3() {
    meta.mbr = meta.mbr ^ hdr.instr[2].arg;
}

action memory_read_s3() {
    meta.mbr = heap_read_s3.execute((bit<32>)meta.mar);
}

action memory_write_s3() {
    heap_write_s3.execute((bit<32>)meta.mar);
}action mar_load_s4() {
    meta.mar = hdr.instr[3].arg;
}

action mbr1_load_s4() {
    meta.mbr = hdr.instr[3].arg;
}

action mbr2_load_s4() {
    meta.mbr2 = hdr.instr[3].arg;
}

action mbr_add_s4() {
    meta.mbr = meta.mbr + hdr.instr[3].arg;
}

action mar_add_s4() {
    meta.mar = meta.mar + hdr.instr[3].arg;
}

action jump_s4() {
    meta.disabled = 1;
    meta.pc = hdr.instr[3].goto;
}

action attempt_rejoin_s4() {
    meta.disabled = (meta.pc ^ hdr.instr[3].goto);
}

action bit_and_mbr_s4() {
    meta.mbr = meta.mbr & hdr.instr[3].arg;
}

action bit_and_mar_s4() {
    meta.mar = meta.mar & hdr.instr[3].arg;
}

action mbr_equals_arg_s4() {
    meta.mbr = meta.mbr ^ hdr.instr[3].arg;
}

action memory_read_s4() {
    meta.mbr = heap_read_s4.execute((bit<32>)meta.mar);
}

action memory_write_s4() {
    heap_write_s4.execute((bit<32>)meta.mar);
}action mar_load_s5() {
    meta.mar = hdr.instr[4].arg;
}

action mbr1_load_s5() {
    meta.mbr = hdr.instr[4].arg;
}

action mbr2_load_s5() {
    meta.mbr2 = hdr.instr[4].arg;
}

action mbr_add_s5() {
    meta.mbr = meta.mbr + hdr.instr[4].arg;
}

action mar_add_s5() {
    meta.mar = meta.mar + hdr.instr[4].arg;
}

action jump_s5() {
    meta.disabled = 1;
    meta.pc = hdr.instr[4].goto;
}

action attempt_rejoin_s5() {
    meta.disabled = (meta.pc ^ hdr.instr[4].goto);
}

action bit_and_mbr_s5() {
    meta.mbr = meta.mbr & hdr.instr[4].arg;
}

action bit_and_mar_s5() {
    meta.mar = meta.mar & hdr.instr[4].arg;
}

action mbr_equals_arg_s5() {
    meta.mbr = meta.mbr ^ hdr.instr[4].arg;
}

action memory_read_s5() {
    meta.mbr = heap_read_s5.execute((bit<32>)meta.mar);
}

action memory_write_s5() {
    heap_write_s5.execute((bit<32>)meta.mar);
}action mar_load_s6() {
    meta.mar = hdr.instr[5].arg;
}

action mbr1_load_s6() {
    meta.mbr = hdr.instr[5].arg;
}

action mbr2_load_s6() {
    meta.mbr2 = hdr.instr[5].arg;
}

action mbr_add_s6() {
    meta.mbr = meta.mbr + hdr.instr[5].arg;
}

action mar_add_s6() {
    meta.mar = meta.mar + hdr.instr[5].arg;
}

action jump_s6() {
    meta.disabled = 1;
    meta.pc = hdr.instr[5].goto;
}

action attempt_rejoin_s6() {
    meta.disabled = (meta.pc ^ hdr.instr[5].goto);
}

action bit_and_mbr_s6() {
    meta.mbr = meta.mbr & hdr.instr[5].arg;
}

action bit_and_mar_s6() {
    meta.mar = meta.mar & hdr.instr[5].arg;
}

action mbr_equals_arg_s6() {
    meta.mbr = meta.mbr ^ hdr.instr[5].arg;
}

action memory_read_s6() {
    meta.mbr = heap_read_s6.execute((bit<32>)meta.mar);
}

action memory_write_s6() {
    heap_write_s6.execute((bit<32>)meta.mar);
}action mar_load_s7() {
    meta.mar = hdr.instr[6].arg;
}

action mbr1_load_s7() {
    meta.mbr = hdr.instr[6].arg;
}

action mbr2_load_s7() {
    meta.mbr2 = hdr.instr[6].arg;
}

action mbr_add_s7() {
    meta.mbr = meta.mbr + hdr.instr[6].arg;
}

action mar_add_s7() {
    meta.mar = meta.mar + hdr.instr[6].arg;
}

action jump_s7() {
    meta.disabled = 1;
    meta.pc = hdr.instr[6].goto;
}

action attempt_rejoin_s7() {
    meta.disabled = (meta.pc ^ hdr.instr[6].goto);
}

action bit_and_mbr_s7() {
    meta.mbr = meta.mbr & hdr.instr[6].arg;
}

action bit_and_mar_s7() {
    meta.mar = meta.mar & hdr.instr[6].arg;
}

action mbr_equals_arg_s7() {
    meta.mbr = meta.mbr ^ hdr.instr[6].arg;
}

action memory_read_s7() {
    meta.mbr = heap_read_s7.execute((bit<32>)meta.mar);
}

action memory_write_s7() {
    heap_write_s7.execute((bit<32>)meta.mar);
}action mar_load_s8() {
    meta.mar = hdr.instr[7].arg;
}

action mbr1_load_s8() {
    meta.mbr = hdr.instr[7].arg;
}

action mbr2_load_s8() {
    meta.mbr2 = hdr.instr[7].arg;
}

action mbr_add_s8() {
    meta.mbr = meta.mbr + hdr.instr[7].arg;
}

action mar_add_s8() {
    meta.mar = meta.mar + hdr.instr[7].arg;
}

action jump_s8() {
    meta.disabled = 1;
    meta.pc = hdr.instr[7].goto;
}

action attempt_rejoin_s8() {
    meta.disabled = (meta.pc ^ hdr.instr[7].goto);
}

action bit_and_mbr_s8() {
    meta.mbr = meta.mbr & hdr.instr[7].arg;
}

action bit_and_mar_s8() {
    meta.mar = meta.mar & hdr.instr[7].arg;
}

action mbr_equals_arg_s8() {
    meta.mbr = meta.mbr ^ hdr.instr[7].arg;
}

action memory_read_s8() {
    meta.mbr = heap_read_s8.execute((bit<32>)meta.mar);
}

action memory_write_s8() {
    heap_write_s8.execute((bit<32>)meta.mar);
}action mar_load_s9() {
    meta.mar = hdr.instr[8].arg;
}

action mbr1_load_s9() {
    meta.mbr = hdr.instr[8].arg;
}

action mbr2_load_s9() {
    meta.mbr2 = hdr.instr[8].arg;
}

action mbr_add_s9() {
    meta.mbr = meta.mbr + hdr.instr[8].arg;
}

action mar_add_s9() {
    meta.mar = meta.mar + hdr.instr[8].arg;
}

action jump_s9() {
    meta.disabled = 1;
    meta.pc = hdr.instr[8].goto;
}

action attempt_rejoin_s9() {
    meta.disabled = (meta.pc ^ hdr.instr[8].goto);
}

action bit_and_mbr_s9() {
    meta.mbr = meta.mbr & hdr.instr[8].arg;
}

action bit_and_mar_s9() {
    meta.mar = meta.mar & hdr.instr[8].arg;
}

action mbr_equals_arg_s9() {
    meta.mbr = meta.mbr ^ hdr.instr[8].arg;
}

action memory_read_s9() {
    meta.mbr = heap_read_s9.execute((bit<32>)meta.mar);
}

action memory_write_s9() {
    heap_write_s9.execute((bit<32>)meta.mar);
}action mar_load_s10() {
    meta.mar = hdr.instr[9].arg;
}

action mbr1_load_s10() {
    meta.mbr = hdr.instr[9].arg;
}

action mbr2_load_s10() {
    meta.mbr2 = hdr.instr[9].arg;
}

action mbr_add_s10() {
    meta.mbr = meta.mbr + hdr.instr[9].arg;
}

action mar_add_s10() {
    meta.mar = meta.mar + hdr.instr[9].arg;
}

action jump_s10() {
    meta.disabled = 1;
    meta.pc = hdr.instr[9].goto;
}

action attempt_rejoin_s10() {
    meta.disabled = (meta.pc ^ hdr.instr[9].goto);
}

action bit_and_mbr_s10() {
    meta.mbr = meta.mbr & hdr.instr[9].arg;
}

action bit_and_mar_s10() {
    meta.mar = meta.mar & hdr.instr[9].arg;
}

action mbr_equals_arg_s10() {
    meta.mbr = meta.mbr ^ hdr.instr[9].arg;
}

action memory_read_s10() {
    meta.mbr = heap_read_s10.execute((bit<32>)meta.mar);
}

action memory_write_s10() {
    heap_write_s10.execute((bit<32>)meta.mar);
}

    // GENERATED: TABLES

    

table instruction_1 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[0].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_2 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[1].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_3 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[2].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_4 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[3].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_5 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[4].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_6 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[5].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_7 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[6].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_8 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[7].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_9 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[8].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
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
    }
}

// create a set of parallel tables for mutually exclusive actions

table instruction_10 {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[9].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        /*meta.mbr                : range;
        meta.mar                : range;*/
    }
    actions = {
        drop;
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
        copy_acc_mbr;
        mar_load_s10;
mbr1_load_s10;
mbr2_load_s10;
mbr_add_s10;
mar_add_s10;
jump_s10;
attempt_rejoin_s10;
bit_and_mbr_s10;
bit_and_mar_s10;
mbr_equals_arg_s10;
memory_read_s10;
memory_write_s10;
    }
}

// create a set of parallel tables for mutually exclusive actions

    // control flow

    apply {
        if (hdr.ipv4.isValid()) {
            if (ipv4_host.apply().miss) {
                ipv4_lpm.apply();
            }
        }
        instruction_1.apply();
		instruction_2.apply();
		instruction_3.apply();
		instruction_4.apply();
		instruction_5.apply();
		instruction_6.apply();
		instruction_7.apply();
		instruction_8.apply();
		instruction_9.apply();
		instruction_10.apply();
    }
}