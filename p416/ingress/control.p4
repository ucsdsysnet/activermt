

control Ingress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    

Register<bit<32>, bit<32>>(32w94208) heap_s0;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_conditional_write_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_conditional_increment_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    R/W memory object.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_read_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_write_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_accumulate_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_conditional_rw_max_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr) {
            obj = hdr.meta.mbr;
        } 
    }
};*/

/*
    Conditional write (if not zero). 
    Useful in implementing collision chains (object cannot be zero).
    Cases: obj = 0, obj = mbr2, obj != mbr2.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_conditional_rw_zero_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // if(obj == hdr.meta.mbr2) {
        //     rv = 0;    
        // } 
        if(obj == 0) {
            obj = hdr.meta.mbr2;
            // rv = 0;
        } else {
            rv = hdr.meta.mbr2 - obj;
        }
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_conditional_increment_s0 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};*/

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s0) heap_bulk_write_s0 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_0;
    }
};*/

Register<bit<32>, bit<32>>(32w94208) heap_s1;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_conditional_write_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_conditional_increment_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    R/W memory object.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_read_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_write_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_accumulate_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_conditional_rw_max_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr) {
            obj = hdr.meta.mbr;
        } 
    }
};*/

/*
    Conditional write (if not zero). 
    Useful in implementing collision chains (object cannot be zero).
    Cases: obj = 0, obj = mbr2, obj != mbr2.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_conditional_rw_zero_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // if(obj == hdr.meta.mbr2) {
        //     rv = 0;    
        // } 
        if(obj == 0) {
            obj = hdr.meta.mbr2;
            // rv = 0;
        } else {
            rv = hdr.meta.mbr2 - obj;
        }
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_conditional_increment_s1 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};*/

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s1) heap_bulk_write_s1 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_1;
    }
};*/

Register<bit<32>, bit<32>>(32w94208) heap_s2;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_conditional_write_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_conditional_increment_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    R/W memory object.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_read_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_write_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_accumulate_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_conditional_rw_max_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr) {
            obj = hdr.meta.mbr;
        } 
    }
};*/

/*
    Conditional write (if not zero). 
    Useful in implementing collision chains (object cannot be zero).
    Cases: obj = 0, obj = mbr2, obj != mbr2.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_conditional_rw_zero_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // if(obj == hdr.meta.mbr2) {
        //     rv = 0;    
        // } 
        if(obj == 0) {
            obj = hdr.meta.mbr2;
            // rv = 0;
        } else {
            rv = hdr.meta.mbr2 - obj;
        }
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_conditional_increment_s2 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};*/

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s2) heap_bulk_write_s2 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_2;
    }
};*/

Register<bit<32>, bit<32>>(32w94208) heap_s3;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_conditional_write_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_conditional_increment_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    R/W memory object.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_read_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_write_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_accumulate_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_conditional_rw_max_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr) {
            obj = hdr.meta.mbr;
        } 
    }
};*/

/*
    Conditional write (if not zero). 
    Useful in implementing collision chains (object cannot be zero).
    Cases: obj = 0, obj = mbr2, obj != mbr2.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_conditional_rw_zero_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // if(obj == hdr.meta.mbr2) {
        //     rv = 0;    
        // } 
        if(obj == 0) {
            obj = hdr.meta.mbr2;
            // rv = 0;
        } else {
            rv = hdr.meta.mbr2 - obj;
        }
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_conditional_increment_s3 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};*/

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s3) heap_bulk_write_s3 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_3;
    }
};*/

Register<bit<32>, bit<32>>(32w94208) heap_s4;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_conditional_write_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(hdr.meta.mbr2 != 0) {
            obj = hdr.meta.mbr;
        } else {
            obj = obj + hdr.meta.mbr;
        }
    }
};*/

/*
    Increment by mbr (eg. 1) if current value is less than mbr2.
    [special case] Read: hdr.meta.mbr2 = 0.
    [special case] Increment: hdr.meta.mbr2 = 0xFFFF.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_conditional_increment_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr2) {
            obj = obj + hdr.meta.mbr;
        } 
    }
};*/

/*
    R/W memory object.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_read_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_write_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_accumulate_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_conditional_rw_max_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
        if(obj < hdr.meta.mbr) {
            obj = hdr.meta.mbr;
        } 
    }
};*/

/*
    Conditional write (if not zero). 
    Useful in implementing collision chains (object cannot be zero).
    Cases: obj = 0, obj = mbr2, obj != mbr2.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_conditional_rw_zero_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // if(obj == hdr.meta.mbr2) {
        //     rv = 0;    
        // } 
        if(obj == 0) {
            obj = hdr.meta.mbr2;
            // rv = 0;
        } else {
            rv = hdr.meta.mbr2 - obj;
        }
    }
};

/*
    Increment if condition is true.
    [special case] Increment: hdr.meta.mbr = REGMAX.
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_conditional_increment_s4 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = 0;
        if(obj < hdr.meta.mbr) {
            obj = obj + 1;
            rv = obj;
        } else if(obj < hdr.meta.mbr2) {
            obj = hdr.meta.mbr2;
            rv = obj;
        } 
    }
};*/

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s4) heap_bulk_write_s4 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_4;
    }
};*/

    

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = true,
    msb         = false,
    extended    = true,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s0;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s0) crc_16_s0;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = false,
    msb         = false,
    extended    = true,
    init        = 0x0000,
    xor         = 0x0000
) crc_16_poly_s1;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s1) crc_16_s1;

CRCPolynomial<bit<16>>(
    coeff       = 0x18005,
    reversed    = false,
    msb         = false,
    extended    = true,
    init        = 0x800D,
    xor         = 0x0000
) crc_16_poly_s2;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s2) crc_16_s2;

CRCPolynomial<bit<16>>(
    coeff       = 0x10589,
    reversed    = false,
    msb         = false,
    extended    = true,
    init        = 0x0001,
    xor         = 0x0001
) crc_16_poly_s3;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s3) crc_16_s3;

CRCPolynomial<bit<16>>(
    coeff       = 0x13D65,
    reversed    = true,
    msb         = false,
    extended    = true,
    init        = 0xFFFF,
    xor         = 0xFFFF
) crc_16_poly_s4;

Hash<bit<16>>(HashAlgorithm_t.CUSTOM, crc_16_poly_s4) crc_16_s4;

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

    /*action uncomplete() {
    hdr.meta.complete = 0;
}*/

action fork() {
    hdr.meta.duplicate = 1;
}

action copy_mbr2_mbr1() {
    hdr.meta.mbr2 = hdr.meta.mbr;
}

action copy_mbr1_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr2;
}

/*action mark_packet() {
    hdr.ih.flag_marked = 1;
}*/

// action memfault() {
//     hdr.ih.flag_mfault = 1;
//     complete();
//     rts();
// }

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

action copy_inc_mbr() {
    hdr.meta.inc = hdr.meta.mbr;
}

action copy_hash_data_mbr() {
    hdr.meta.hash_data_0 = hdr.meta.mbr;
}

action copy_hash_data_mbr2() {
    hdr.meta.hash_data_1 = hdr.meta.mbr2;
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

action load_salt() {
    hdr.meta.mbr = CONST_SALT;
}

action not_mbr() {
    hdr.meta.mbr = ~hdr.meta.mbr;
}

action mbr_or_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr | hdr.meta.mbr2;
}

action mbr_subtract_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr - hdr.meta.mbr2;
}

action swap_mbr_mbr2() {
    bit<32> tmp;
    tmp = hdr.meta.mbr;
    hdr.meta.mbr = hdr.meta.mbr2;
    hdr.meta.mbr2 = tmp;
}

action max_mbr_mbr2() {
    hdr.meta.mbr = (hdr.meta.mbr >= hdr.meta.mbr2 ? hdr.meta.mbr : hdr.meta.mbr2);
}

/*action addr_mask_apply() {
    hdr.meta.mar = hdr.meta.mar & hdr.meta.paddr_mask;
}*/

/*action addr_offset_apply() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.paddr_offset;
}*/

action addr_mask_apply(bit<32> addr_mask) {
    hdr.meta.mar = hdr.meta.mar & addr_mask;
}

action addr_offset_apply(bit<32> offset) {
    hdr.meta.mar = hdr.meta.mar + offset;
}

action mar_load() {
    hdr.meta.mar = hdr.data.data_0 & 0xFFFFF;
}

action mbr_load() {
    hdr.meta.mbr = hdr.data.data_1;
}

action mbr2_load() {
    hdr.meta.mbr2 = hdr.data.data_2;
}

action mbr_store() {
    hdr.data.data_3 = hdr.meta.mbr;
}

action mbr_store_alt() {
    hdr.data.data_1 = hdr.meta.mbr;
}

action mbr_store_alt_2() {
    hdr.data.data_2 = hdr.meta.mbr;
}

// action mbr_store_extended_data_0() {
//     hdr.extended_data[0].data = hdr.meta.mbr;
//     // hdr.extended_data[0].setValid();
// }

// action mbr_store_extended_data_1() {
//     hdr.extended_data[1].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_2() {
//     hdr.extended_data[2].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_3() {
//     hdr.extended_data[3].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_4() {
//     hdr.extended_data[4].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_5() {
//     hdr.extended_data[5].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_6() {
//     hdr.extended_data[6].data = hdr.meta.mbr;
// }

// action mbr_store_extended_data_7() {
//     hdr.extended_data[7].data = hdr.meta.mbr;
// }
// action mar_load_d0() {
//     hdr.meta.mar = hdr.data.data_0 & 0xFFFFF;
// }
// action mbr_load_d0() {
//     hdr.meta.mbr = hdr.data.data_0;
// }
// action mbr2_load_d0() {
//     hdr.meta.mbr2 = hdr.data.data_0;
// }
// action d0_load_mbr() {
//     hdr.data.data_0 = hdr.meta.mbr;
// }
// action addrmap_load_d0() {
//     hdr.meta.paddr_mask = hdr.data.data_0;
//     hdr.meta.paddr_offset = hdr.data.data_0 >> 16;
// }
action mbr_equals_d0() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_0;
}
// action mar_load_d1() {
//     hdr.meta.mar = hdr.data.data_1 & 0xFFFFF;
// }
// action mbr_load_d1() {
//     hdr.meta.mbr = hdr.data.data_1;
// }
// action mbr2_load_d1() {
//     hdr.meta.mbr2 = hdr.data.data_1;
// }
// action d1_load_mbr() {
//     hdr.data.data_1 = hdr.meta.mbr;
// }
// action addrmap_load_d1() {
//     hdr.meta.paddr_mask = hdr.data.data_1;
//     hdr.meta.paddr_offset = hdr.data.data_1 >> 16;
// }
action mbr_equals_d1() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_1;
}
// action mar_load_d2() {
//     hdr.meta.mar = hdr.data.data_2 & 0xFFFFF;
// }
// action mbr_load_d2() {
//     hdr.meta.mbr = hdr.data.data_2;
// }
// action mbr2_load_d2() {
//     hdr.meta.mbr2 = hdr.data.data_2;
// }
// action d2_load_mbr() {
//     hdr.data.data_2 = hdr.meta.mbr;
// }
// action addrmap_load_d2() {
//     hdr.meta.paddr_mask = hdr.data.data_2;
//     hdr.meta.paddr_offset = hdr.data.data_2 >> 16;
// }
action mbr_equals_d2() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_2;
}
// action mar_load_d3() {
//     hdr.meta.mar = hdr.data.data_3 & 0xFFFFF;
// }
// action mbr_load_d3() {
//     hdr.meta.mbr = hdr.data.data_3;
// }
// action mbr2_load_d3() {
//     hdr.meta.mbr2 = hdr.data.data_3;
// }
// action d3_load_mbr() {
//     hdr.data.data_3 = hdr.meta.mbr;
// }
// action addrmap_load_d3() {
//     hdr.meta.paddr_mask = hdr.data.data_3;
//     hdr.meta.paddr_offset = hdr.data.data_3 >> 16;
// }
action mbr_equals_d3() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.data.data_3;
}
action jump_s0() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s0() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[0].goto);
}

/*action memory_bulk_read_s0() {
    hdr.bulk_data.data_0 = heap_read_s0.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s0() {
    heap_bulk_write_s0.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s0() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s0.execute(hdr.meta.mar);
}

action memory_write_s0() {
    heap_write_s0.execute(hdr.meta.mar);
}

action memory_increment_s0() {
    hdr.meta.mbr = heap_accumulate_s0.execute(hdr.meta.mar);
}

/*action memory_write_max_s0() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s0.execute(hdr.meta.mar);
}*/

action memory_write_zero_s0() {
    hdr.meta.mbr = heap_conditional_rw_zero_s0.execute(hdr.meta.mar);
}

action memory_minread_s0() {
    hdr.meta.mbr = heap_read_s0.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s0() {
    hdr.meta.mbr = heap_accumulate_s0.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s0() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s0.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s0() {
    hdr.meta.mar = (bit<32>)crc_16_s0.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s1() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s1() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[1].goto);
}

/*action memory_bulk_read_s1() {
    hdr.bulk_data.data_1 = heap_read_s1.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s1() {
    heap_bulk_write_s1.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s1() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s1.execute(hdr.meta.mar);
}

action memory_write_s1() {
    heap_write_s1.execute(hdr.meta.mar);
}

action memory_increment_s1() {
    hdr.meta.mbr = heap_accumulate_s1.execute(hdr.meta.mar);
}

/*action memory_write_max_s1() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s1.execute(hdr.meta.mar);
}*/

action memory_write_zero_s1() {
    hdr.meta.mbr = heap_conditional_rw_zero_s1.execute(hdr.meta.mar);
}

action memory_minread_s1() {
    hdr.meta.mbr = heap_read_s1.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s1() {
    hdr.meta.mbr = heap_accumulate_s1.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s1() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s1.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s1() {
    hdr.meta.mar = (bit<32>)crc_16_s1.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s2() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s2() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[2].goto);
}

/*action memory_bulk_read_s2() {
    hdr.bulk_data.data_2 = heap_read_s2.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s2() {
    heap_bulk_write_s2.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s2() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s2.execute(hdr.meta.mar);
}

action memory_write_s2() {
    heap_write_s2.execute(hdr.meta.mar);
}

action memory_increment_s2() {
    hdr.meta.mbr = heap_accumulate_s2.execute(hdr.meta.mar);
}

/*action memory_write_max_s2() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s2.execute(hdr.meta.mar);
}*/

action memory_write_zero_s2() {
    hdr.meta.mbr = heap_conditional_rw_zero_s2.execute(hdr.meta.mar);
}

action memory_minread_s2() {
    hdr.meta.mbr = heap_read_s2.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s2() {
    hdr.meta.mbr = heap_accumulate_s2.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s2() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s2.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s2() {
    hdr.meta.mar = (bit<32>)crc_16_s2.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s3() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s3() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[3].goto);
}

/*action memory_bulk_read_s3() {
    hdr.bulk_data.data_3 = heap_read_s3.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s3() {
    heap_bulk_write_s3.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s3() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s3.execute(hdr.meta.mar);
}

action memory_write_s3() {
    heap_write_s3.execute(hdr.meta.mar);
}

action memory_increment_s3() {
    hdr.meta.mbr = heap_accumulate_s3.execute(hdr.meta.mar);
}

/*action memory_write_max_s3() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s3.execute(hdr.meta.mar);
}*/

action memory_write_zero_s3() {
    hdr.meta.mbr = heap_conditional_rw_zero_s3.execute(hdr.meta.mar);
}

action memory_minread_s3() {
    hdr.meta.mbr = heap_read_s3.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s3() {
    hdr.meta.mbr = heap_accumulate_s3.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s3() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s3.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s3() {
    hdr.meta.mar = (bit<32>)crc_16_s3.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s4() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s4() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[4].goto);
}

/*action memory_bulk_read_s4() {
    hdr.bulk_data.data_4 = heap_read_s4.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s4() {
    heap_bulk_write_s4.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s4() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s4.execute(hdr.meta.mar);
}

action memory_write_s4() {
    heap_write_s4.execute(hdr.meta.mar);
}

action memory_increment_s4() {
    hdr.meta.mbr = heap_accumulate_s4.execute(hdr.meta.mar);
}

/*action memory_write_max_s4() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s4.execute(hdr.meta.mar);
}*/

action memory_write_zero_s4() {
    hdr.meta.mbr = heap_conditional_rw_zero_s4.execute(hdr.meta.mar);
}

action memory_minread_s4() {
    hdr.meta.mbr = heap_read_s4.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s4() {
    hdr.meta.mbr = heap_accumulate_s4.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s4() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s4.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s4() {
    hdr.meta.mar = (bit<32>)crc_16_s4.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}

    // GENERATED: TABLES

    action load_instr_0(bit<8> opcode, bit<1> goto) {
    hdr.instr[0].opcode = opcode;
    hdr.instr[0].goto = goto;
}

table loader_0 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_0;
    }
}

action load_instr_1(bit<8> opcode, bit<1> goto) {
    hdr.instr[1].opcode = opcode;
    hdr.instr[1].goto = goto;
}

table loader_1 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_1;
    }
}

action load_instr_2(bit<8> opcode, bit<1> goto) {
    hdr.instr[2].opcode = opcode;
    hdr.instr[2].goto = goto;
}

table loader_2 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_2;
    }
}

action load_instr_3(bit<8> opcode, bit<1> goto) {
    hdr.instr[3].opcode = opcode;
    hdr.instr[3].goto = goto;
}

table loader_3 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_3;
    }
}

action load_instr_4(bit<8> opcode, bit<1> goto) {
    hdr.instr[4].opcode = opcode;
    hdr.instr[4].goto = goto;
}

table loader_4 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_4;
    }
}

action load_instr_5(bit<8> opcode, bit<1> goto) {
    hdr.instr[5].opcode = opcode;
    hdr.instr[5].goto = goto;
}

table loader_5 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_5;
    }
}

action load_instr_6(bit<8> opcode, bit<1> goto) {
    hdr.instr[6].opcode = opcode;
    hdr.instr[6].goto = goto;
}

table loader_6 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_6;
    }
}

action load_instr_7(bit<8> opcode, bit<1> goto) {
    hdr.instr[7].opcode = opcode;
    hdr.instr[7].goto = goto;
}

table loader_7 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_7;
    }
}

action load_instr_8(bit<8> opcode, bit<1> goto) {
    hdr.instr[8].opcode = opcode;
    hdr.instr[8].goto = goto;
}

table loader_8 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_8;
    }
}

action load_instr_9(bit<8> opcode, bit<1> goto) {
    hdr.instr[9].opcode = opcode;
    hdr.instr[9].goto = goto;
}

table loader_9 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_9;
    }
}

action load_instr_10(bit<8> opcode, bit<1> goto) {
    hdr.instr[10].opcode = opcode;
    hdr.instr[10].goto = goto;
}

table loader_10 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_10;
    }
}

action load_instr_11(bit<8> opcode, bit<1> goto) {
    hdr.instr[11].opcode = opcode;
    hdr.instr[11].goto = goto;
}

table loader_11 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_11;
    }
}

action load_instr_12(bit<8> opcode, bit<1> goto) {
    hdr.instr[12].opcode = opcode;
    hdr.instr[12].goto = goto;
}

table loader_12 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_12;
    }
}

action load_instr_13(bit<8> opcode, bit<1> goto) {
    hdr.instr[13].opcode = opcode;
    hdr.instr[13].goto = goto;
}

table loader_13 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_13;
    }
}

action load_instr_14(bit<8> opcode, bit<1> goto) {
    hdr.instr[14].opcode = opcode;
    hdr.instr[14].goto = goto;
}

table loader_14 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_14;
    }
}

action load_instr_15(bit<8> opcode, bit<1> goto) {
    hdr.instr[15].opcode = opcode;
    hdr.instr[15].goto = goto;
}

table loader_15 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_15;
    }
}

action load_instr_16(bit<8> opcode, bit<1> goto) {
    hdr.instr[16].opcode = opcode;
    hdr.instr[16].goto = goto;
}

table loader_16 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_16;
    }
}

action load_instr_17(bit<8> opcode, bit<1> goto) {
    hdr.instr[17].opcode = opcode;
    hdr.instr[17].goto = goto;
}

table loader_17 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_17;
    }
}

action load_instr_18(bit<8> opcode, bit<1> goto) {
    hdr.instr[18].opcode = opcode;
    hdr.instr[18].goto = goto;
}

table loader_18 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_18;
    }
}

action load_instr_19(bit<8> opcode, bit<1> goto) {
    hdr.instr[19].opcode = opcode;
    hdr.instr[19].goto = goto;
}

table loader_19 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_19;
    }
}

action load_instr_20(bit<8> opcode, bit<1> goto) {
    hdr.instr[20].opcode = opcode;
    hdr.instr[20].goto = goto;
}

table loader_20 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_20;
    }
}

action load_instr_21(bit<8> opcode, bit<1> goto) {
    hdr.instr[21].opcode = opcode;
    hdr.instr[21].goto = goto;
}

table loader_21 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_21;
    }
}

action load_instr_22(bit<8> opcode, bit<1> goto) {
    hdr.instr[22].opcode = opcode;
    hdr.instr[22].goto = goto;
}

table loader_22 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_22;
    }
}

action load_instr_23(bit<8> opcode, bit<1> goto) {
    hdr.instr[23].opcode = opcode;
    hdr.instr[23].goto = goto;
}

table loader_23 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_23;
    }
}

action load_instr_24(bit<8> opcode, bit<1> goto) {
    hdr.instr[24].opcode = opcode;
    hdr.instr[24].goto = goto;
}

table loader_24 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_24;
    }
}

action load_instr_25(bit<8> opcode, bit<1> goto) {
    hdr.instr[25].opcode = opcode;
    hdr.instr[25].goto = goto;
}

table loader_25 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_25;
    }
}

action load_instr_26(bit<8> opcode, bit<1> goto) {
    hdr.instr[26].opcode = opcode;
    hdr.instr[26].goto = goto;
}

table loader_26 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_26;
    }
}

action load_instr_27(bit<8> opcode, bit<1> goto) {
    hdr.instr[27].opcode = opcode;
    hdr.instr[27].goto = goto;
}

table loader_27 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_27;
    }
}

action load_instr_28(bit<8> opcode, bit<1> goto) {
    hdr.instr[28].opcode = opcode;
    hdr.instr[28].goto = goto;
}

table loader_28 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_28;
    }
}

action load_instr_29(bit<8> opcode, bit<1> goto) {
    hdr.instr[29].opcode = opcode;
    hdr.instr[29].goto = goto;
}

table loader_29 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_29;
    }
}

action load_instr_30(bit<8> opcode, bit<1> goto) {
    hdr.instr[30].opcode = opcode;
    hdr.instr[30].goto = goto;
}

table loader_30 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_30;
    }
}

action load_instr_31(bit<8> opcode, bit<1> goto) {
    hdr.instr[31].opcode = opcode;
    hdr.instr[31].goto = goto;
}

table loader_31 {
    key = {
        hdr.ih.opt_data : exact;
    }
    actions = {
        load_instr_31;
    }
}

    

table instruction_0 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[0].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : lpm;
        //hdr.meta.carry                          : exact;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        complete;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        fetch_queue;
        fetch_qdelay;
        fetch_pktcount;
        fork;
		copy_mbr2_mbr1;
		copy_mbr1_mbr2;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		copy_hash_data_mbr2;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		load_salt;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load;
		mbr_load;
		mbr2_load;
		mbr_store;
		mbr_store_alt;
		mbr_store_alt_2;
		mbr_equals_d0;
		mbr_equals_d1;
		mbr_equals_d2;
		mbr_equals_d3;
		jump_s0;
		attempt_rejoin_s0;
		memory_read_s0;
		memory_write_s0;
		memory_increment_s0;
		memory_write_zero_s0;
		memory_minread_s0;
		memory_minreadinc_s0;
		hash_s0;
    }
    size = 640;
}

action get_allocation_s0(bit<32> offset_ig, bit<32> size_ig, bit<32> offset_eg, bit<32> size_eg) {
    hdr.alloc[0].setValid();
    hdr.alloc[0].offset = offset_ig;
    hdr.alloc[0].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(0)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(0)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(0)].size = size_eg;
}

action default_allocation_s0() {
    hdr.alloc[0].setValid();
    hdr.alloc[EG_STAGE_OFFSET(0)].setValid();
}

table allocation_0 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s0;
        default_allocation_s0;
    }
    //default_action = default_allocation_s0;
}

table instruction_1 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[1].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : lpm;
        //hdr.meta.carry                          : exact;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        complete;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        fetch_queue;
        fetch_qdelay;
        fetch_pktcount;
        fork;
		copy_mbr2_mbr1;
		copy_mbr1_mbr2;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		copy_hash_data_mbr2;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		load_salt;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load;
		mbr_load;
		mbr2_load;
		mbr_store;
		mbr_store_alt;
		mbr_store_alt_2;
		mbr_equals_d0;
		mbr_equals_d1;
		mbr_equals_d2;
		mbr_equals_d3;
		jump_s1;
		attempt_rejoin_s1;
		memory_read_s1;
		memory_write_s1;
		memory_increment_s1;
		memory_write_zero_s1;
		memory_minread_s1;
		memory_minreadinc_s1;
		hash_s1;
    }
    size = 640;
}

action get_allocation_s1(bit<32> offset_ig, bit<32> size_ig, bit<32> offset_eg, bit<32> size_eg) {
    hdr.alloc[1].setValid();
    hdr.alloc[1].offset = offset_ig;
    hdr.alloc[1].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(1)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(1)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(1)].size = size_eg;
}

action default_allocation_s1() {
    hdr.alloc[1].setValid();
    hdr.alloc[EG_STAGE_OFFSET(1)].setValid();
}

table allocation_1 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s1;
        default_allocation_s1;
    }
    //default_action = default_allocation_s1;
}

table instruction_2 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[2].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : lpm;
        //hdr.meta.carry                          : exact;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        complete;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        fetch_queue;
        fetch_qdelay;
        fetch_pktcount;
        fork;
		copy_mbr2_mbr1;
		copy_mbr1_mbr2;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		copy_hash_data_mbr2;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		load_salt;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load;
		mbr_load;
		mbr2_load;
		mbr_store;
		mbr_store_alt;
		mbr_store_alt_2;
		mbr_equals_d0;
		mbr_equals_d1;
		mbr_equals_d2;
		mbr_equals_d3;
		jump_s2;
		attempt_rejoin_s2;
		memory_read_s2;
		memory_write_s2;
		memory_increment_s2;
		memory_write_zero_s2;
		memory_minread_s2;
		memory_minreadinc_s2;
		hash_s2;
    }
    size = 640;
}

action get_allocation_s2(bit<32> offset_ig, bit<32> size_ig, bit<32> offset_eg, bit<32> size_eg) {
    hdr.alloc[2].setValid();
    hdr.alloc[2].offset = offset_ig;
    hdr.alloc[2].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(2)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(2)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(2)].size = size_eg;
}

action default_allocation_s2() {
    hdr.alloc[2].setValid();
    hdr.alloc[EG_STAGE_OFFSET(2)].setValid();
}

table allocation_2 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s2;
        default_allocation_s2;
    }
    //default_action = default_allocation_s2;
}

table instruction_3 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[3].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : lpm;
        //hdr.meta.carry                          : exact;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        complete;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        fetch_queue;
        fetch_qdelay;
        fetch_pktcount;
        fork;
		copy_mbr2_mbr1;
		copy_mbr1_mbr2;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		copy_hash_data_mbr2;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		load_salt;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load;
		mbr_load;
		mbr2_load;
		mbr_store;
		mbr_store_alt;
		mbr_store_alt_2;
		mbr_equals_d0;
		mbr_equals_d1;
		mbr_equals_d2;
		mbr_equals_d3;
		jump_s3;
		attempt_rejoin_s3;
		memory_read_s3;
		memory_write_s3;
		memory_increment_s3;
		memory_write_zero_s3;
		memory_minread_s3;
		memory_minreadinc_s3;
		hash_s3;
    }
    size = 640;
}

action get_allocation_s3(bit<32> offset_ig, bit<32> size_ig, bit<32> offset_eg, bit<32> size_eg) {
    hdr.alloc[3].setValid();
    hdr.alloc[3].offset = offset_ig;
    hdr.alloc[3].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(3)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(3)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(3)].size = size_eg;
}

action default_allocation_s3() {
    hdr.alloc[3].setValid();
    hdr.alloc[EG_STAGE_OFFSET(3)].setValid();
}

table allocation_3 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s3;
        default_allocation_s3;
    }
    //default_action = default_allocation_s3;
}

table instruction_4 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[4].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        hdr.meta.mbr                            : lpm;
        //hdr.meta.carry                          : exact;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        complete;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        fetch_queue;
        fetch_qdelay;
        fetch_pktcount;
        fork;
		copy_mbr2_mbr1;
		copy_mbr1_mbr2;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		copy_hash_data_mbr2;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		load_salt;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load;
		mbr_load;
		mbr2_load;
		mbr_store;
		mbr_store_alt;
		mbr_store_alt_2;
		mbr_equals_d0;
		mbr_equals_d1;
		mbr_equals_d2;
		mbr_equals_d3;
		jump_s4;
		attempt_rejoin_s4;
		memory_read_s4;
		memory_write_s4;
		memory_increment_s4;
		memory_write_zero_s4;
		memory_minread_s4;
		memory_minreadinc_s4;
		hash_s4;
    }
    size = 640;
}

action get_allocation_s4(bit<32> offset_ig, bit<32> size_ig, bit<32> offset_eg, bit<32> size_eg) {
    hdr.alloc[4].setValid();
    hdr.alloc[4].offset = offset_ig;
    hdr.alloc[4].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(4)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(4)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(4)].size = size_eg;
}

action default_allocation_s4() {
    hdr.alloc[4].setValid();
    hdr.alloc[EG_STAGE_OFFSET(4)].setValid();
}

table allocation_4 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s4;
        default_allocation_s4;
    }
    //default_action = default_allocation_s4;
}

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

    // Third-Party

    
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
    // 

    // control flow

    apply {
        
        vrf = 10w0;
        forward.apply();
        alpm_forward.apply();
        // 
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
        loader_0.apply();
		loader_1.apply();
		loader_2.apply();
		loader_3.apply();
		loader_4.apply();
		loader_5.apply();
		loader_6.apply();
		loader_7.apply();
		loader_8.apply();
		loader_9.apply();
		loader_10.apply();
		loader_11.apply();
		loader_12.apply();
		loader_13.apply();
		loader_14.apply();
		loader_15.apply();
		loader_16.apply();
		loader_17.apply();
		loader_18.apply();
		loader_19.apply();
		loader_20.apply();
		loader_21.apply();
		loader_22.apply();
		loader_23.apply();
		loader_24.apply();
		loader_25.apply();
		loader_26.apply();
		loader_27.apply();
		loader_28.apply();
		loader_29.apply();
		loader_30.apply();
		loader_31.apply();
        if(hdr.instr[0].isValid()) { instruction_0.apply(); hdr.instr[0].setInvalid(); }
		if(hdr.instr[1].isValid()) { instruction_1.apply(); hdr.instr[1].setInvalid(); }
		if(hdr.instr[2].isValid()) { instruction_2.apply(); hdr.instr[2].setInvalid(); }
		if(hdr.instr[3].isValid()) { instruction_3.apply(); hdr.instr[3].setInvalid(); }
		if(hdr.instr[4].isValid()) { instruction_4.apply(); hdr.instr[4].setInvalid(); }
        allocation_0.apply();
		allocation_1.apply();
		allocation_2.apply();
		allocation_3.apply();
		allocation_4.apply();
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