control Ingress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    

Register<bit<32>, bit<32>>(32w65536) heap_s0;

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

Register<bit<32>, bit<32>>(32w65536) heap_s1;

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

Register<bit<32>, bit<32>>(32w65536) heap_s2;

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

Register<bit<32>, bit<32>>(32w65536) heap_s3;

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

Register<bit<32>, bit<32>>(32w65536) heap_s4;

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

Register<bit<32>, bit<32>>(32w65536) heap_s5;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_conditional_write_s5 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_conditional_increment_s5 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_read_s5 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_write_s5 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_accumulate_s5 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_conditional_rw_max_s5 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_conditional_rw_zero_s5 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_conditional_increment_s5 = {
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

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s5) heap_bulk_write_s5 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_5;
    }
};*/

Register<bit<32>, bit<32>>(32w65536) heap_s6;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_conditional_write_s6 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_conditional_increment_s6 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_read_s6 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_write_s6 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_accumulate_s6 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_conditional_rw_max_s6 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_conditional_rw_zero_s6 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_conditional_increment_s6 = {
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

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s6) heap_bulk_write_s6 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_6;
    }
};*/

Register<bit<32>, bit<32>>(32w65536) heap_s7;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_conditional_write_s7 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_conditional_increment_s7 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_read_s7 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_write_s7 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_accumulate_s7 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_conditional_rw_max_s7 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_conditional_rw_zero_s7 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_conditional_increment_s7 = {
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

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s7) heap_bulk_write_s7 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_7;
    }
};*/

Register<bit<32>, bit<32>>(32w65536) heap_s8;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_conditional_write_s8 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_conditional_increment_s8 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_read_s8 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_write_s8 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_accumulate_s8 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_conditional_rw_max_s8 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_conditional_rw_zero_s8 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_conditional_increment_s8 = {
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

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s8) heap_bulk_write_s8 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_8;
    }
};*/

Register<bit<32>, bit<32>>(32w65536) heap_s9;

/*
    Write mbr to register value, return old value.
    [special case] Increment: hdr.meta.mbr2 > 0. 
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_conditional_write_s9 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_conditional_increment_s9 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_read_s9 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        rv = obj;
    }
};

RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_write_s9 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        obj = hdr.meta.mbr;
    }
};

/*
    Accumulate in regval.
*/
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_accumulate_s9 = {
    void apply(inout bit<32> obj, out bit<32> rv) {
        // obj = obj + hdr.meta.inc;
        obj = obj + 1;
        rv = obj;
    }
};

/*
    Conditional write (max).
*/
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_conditional_rw_max_s9 = {
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
RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_conditional_rw_zero_s9 = {
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
/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_conditional_increment_s9 = {
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

/*RegisterAction<bit<32>, bit<32>, bit<32>>(heap_s9) heap_bulk_write_s9 = {
    void apply(inout bit<32> value) {
        value = hdr.bulk_data.data_9;
    }
};*/

    

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

action copy_inc_mbr() {
    hdr.meta.inc = hdr.meta.mbr;
}

action copy_hash_data_mbr() {
    hdr.meta.hash_data_0 = hdr.meta.mbr;
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

/*action load_salt() {
    hdr.meta.mbr = CONST_SALT;
}*/

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
action mar_load_d0() {
    hdr.meta.mar = hdr.data.data_0;
}
action mar_load_d1() {
    hdr.meta.mar = hdr.data.data_1;
}
action mar_load_d2() {
    hdr.meta.mar = hdr.data.data_2;
}
action mar_load_d3() {
    hdr.meta.mar = hdr.data.data_3;
}
action mbr_load_d0() {
    hdr.meta.mbr = hdr.data.data_0;
}
action d0_load_mbr() {
    hdr.data.data_0 = hdr.meta.mbr;
}
action mbr_load_d1() {
    hdr.meta.mbr = hdr.data.data_1;
}
action d1_load_mbr() {
    hdr.data.data_1 = hdr.meta.mbr;
}
action mbr_load_d2() {
    hdr.meta.mbr = hdr.data.data_2;
}
action d2_load_mbr() {
    hdr.data.data_2 = hdr.meta.mbr;
}
action mbr_load_d3() {
    hdr.meta.mbr = hdr.data.data_3;
}
action d3_load_mbr() {
    hdr.data.data_3 = hdr.meta.mbr;
}
action mbr2_load_d0() {
    hdr.meta.mbr2 = hdr.data.data_0;
}
action mbr2_load_d1() {
    hdr.meta.mbr2 = hdr.data.data_1;
}
action mbr2_load_d2() {
    hdr.meta.mbr2 = hdr.data.data_2;
}
action mbr2_load_d3() {
    hdr.meta.mbr2 = hdr.data.data_3;
}
/*action addrmap_load_d0() {
    hdr.meta.paddr_mask = hdr.data.data_0;
    hdr.meta.paddr_offset = hdr.data.data_0 >> 16;
}*/
/*action addrmap_load_d1() {
    hdr.meta.paddr_mask = hdr.data.data_1;
    hdr.meta.paddr_offset = hdr.data.data_1 >> 16;
}*/
/*action addrmap_load_d2() {
    hdr.meta.paddr_mask = hdr.data.data_2;
    hdr.meta.paddr_offset = hdr.data.data_2 >> 16;
}*/
/*action addrmap_load_d3() {
    hdr.meta.paddr_mask = hdr.data.data_3;
    hdr.meta.paddr_offset = hdr.data.data_3 >> 16;
}*/
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
}action jump_s5() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s5() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[5].goto);
}

/*action memory_bulk_read_s5() {
    hdr.bulk_data.data_5 = heap_read_s5.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s5() {
    heap_bulk_write_s5.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s5() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s5.execute(hdr.meta.mar);
}

action memory_write_s5() {
    heap_write_s5.execute(hdr.meta.mar);
}

action memory_increment_s5() {
    hdr.meta.mbr = heap_accumulate_s5.execute(hdr.meta.mar);
}

/*action memory_write_max_s5() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s5.execute(hdr.meta.mar);
}*/

action memory_write_zero_s5() {
    hdr.meta.mbr = heap_conditional_rw_zero_s5.execute(hdr.meta.mar);
}

action memory_minread_s5() {
    hdr.meta.mbr = heap_read_s5.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s5() {
    hdr.meta.mbr = heap_accumulate_s5.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s5() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s5.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s5() {
    hdr.meta.mar = (bit<32>)crc_16_s5.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s6() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s6() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[6].goto);
}

/*action memory_bulk_read_s6() {
    hdr.bulk_data.data_6 = heap_read_s6.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s6() {
    heap_bulk_write_s6.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s6() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s6.execute(hdr.meta.mar);
}

action memory_write_s6() {
    heap_write_s6.execute(hdr.meta.mar);
}

action memory_increment_s6() {
    hdr.meta.mbr = heap_accumulate_s6.execute(hdr.meta.mar);
}

/*action memory_write_max_s6() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s6.execute(hdr.meta.mar);
}*/

action memory_write_zero_s6() {
    hdr.meta.mbr = heap_conditional_rw_zero_s6.execute(hdr.meta.mar);
}

action memory_minread_s6() {
    hdr.meta.mbr = heap_read_s6.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s6() {
    hdr.meta.mbr = heap_accumulate_s6.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s6() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s6.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s6() {
    hdr.meta.mar = (bit<32>)crc_16_s6.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s7() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s7() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[7].goto);
}

/*action memory_bulk_read_s7() {
    hdr.bulk_data.data_7 = heap_read_s7.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s7() {
    heap_bulk_write_s7.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s7() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s7.execute(hdr.meta.mar);
}

action memory_write_s7() {
    heap_write_s7.execute(hdr.meta.mar);
}

action memory_increment_s7() {
    hdr.meta.mbr = heap_accumulate_s7.execute(hdr.meta.mar);
}

/*action memory_write_max_s7() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s7.execute(hdr.meta.mar);
}*/

action memory_write_zero_s7() {
    hdr.meta.mbr = heap_conditional_rw_zero_s7.execute(hdr.meta.mar);
}

action memory_minread_s7() {
    hdr.meta.mbr = heap_read_s7.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s7() {
    hdr.meta.mbr = heap_accumulate_s7.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s7() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s7.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s7() {
    hdr.meta.mar = (bit<32>)crc_16_s7.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s8() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s8() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[8].goto);
}

/*action memory_bulk_read_s8() {
    hdr.bulk_data.data_8 = heap_read_s8.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s8() {
    heap_bulk_write_s8.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s8() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s8.execute(hdr.meta.mar);
}

action memory_write_s8() {
    heap_write_s8.execute(hdr.meta.mar);
}

action memory_increment_s8() {
    hdr.meta.mbr = heap_accumulate_s8.execute(hdr.meta.mar);
}

/*action memory_write_max_s8() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s8.execute(hdr.meta.mar);
}*/

action memory_write_zero_s8() {
    hdr.meta.mbr = heap_conditional_rw_zero_s8.execute(hdr.meta.mar);
}

action memory_minread_s8() {
    hdr.meta.mbr = heap_read_s8.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s8() {
    hdr.meta.mbr = heap_accumulate_s8.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s8() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s8.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s8() {
    hdr.meta.mar = (bit<32>)crc_16_s8.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}action jump_s9() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s9() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[9].goto);
}

/*action memory_bulk_read_s9() {
    hdr.bulk_data.data_9 = heap_read_s9.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s9() {
    heap_bulk_write_s9.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s9() {
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s9.execute(hdr.meta.mar);
}

action memory_write_s9() {
    heap_write_s9.execute(hdr.meta.mar);
}

action memory_increment_s9() {
    hdr.meta.mbr = heap_accumulate_s9.execute(hdr.meta.mar);
}

/*action memory_write_max_s9() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s9.execute(hdr.meta.mar);
}*/

action memory_write_zero_s9() {
    hdr.meta.mbr = heap_conditional_rw_zero_s9.execute(hdr.meta.mar);
}

action memory_minread_s9() {
    hdr.meta.mbr = heap_read_s9.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s9() {
    hdr.meta.mbr = heap_accumulate_s9.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s9() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s9.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s9() {
    hdr.meta.mar = (bit<32>)crc_16_s9.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}

    // GENERATED: TABLES

    

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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
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
    size = 512;
}

action get_allocation_s0(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[0].setValid();
    hdr.alloc[0].start = offset_ig;
    hdr.alloc[0].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(0)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(0)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(0)].end = size_eg;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
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
    size = 512;
}

action get_allocation_s1(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[1].setValid();
    hdr.alloc[1].start = offset_ig;
    hdr.alloc[1].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(1)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(1)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(1)].end = size_eg;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
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
    size = 512;
}

action get_allocation_s2(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[2].setValid();
    hdr.alloc[2].start = offset_ig;
    hdr.alloc[2].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(2)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(2)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(2)].end = size_eg;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
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
    size = 512;
}

action get_allocation_s3(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[3].setValid();
    hdr.alloc[3].start = offset_ig;
    hdr.alloc[3].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(3)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(3)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(3)].end = size_eg;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
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
    size = 512;
}

action get_allocation_s4(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[4].setValid();
    hdr.alloc[4].start = offset_ig;
    hdr.alloc[4].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(4)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(4)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(4)].end = size_eg;
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

table instruction_5 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[5].opcode      : exact;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
		jump_s5;
		attempt_rejoin_s5;
		memory_read_s5;
		memory_write_s5;
		memory_increment_s5;
		memory_write_zero_s5;
		memory_minread_s5;
		memory_minreadinc_s5;
		hash_s5;
    }
    size = 512;
}

action get_allocation_s5(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[5].setValid();
    hdr.alloc[5].start = offset_ig;
    hdr.alloc[5].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(5)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(5)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(5)].end = size_eg;
}

action default_allocation_s5() {
    hdr.alloc[5].setValid();
    hdr.alloc[EG_STAGE_OFFSET(5)].setValid();
}

table allocation_5 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s5;
        default_allocation_s5;
    }
    //default_action = default_allocation_s5;
}

table instruction_6 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[6].opcode      : exact;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
		jump_s6;
		attempt_rejoin_s6;
		memory_read_s6;
		memory_write_s6;
		memory_increment_s6;
		memory_write_zero_s6;
		memory_minread_s6;
		memory_minreadinc_s6;
		hash_s6;
    }
    size = 512;
}

action get_allocation_s6(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[6].setValid();
    hdr.alloc[6].start = offset_ig;
    hdr.alloc[6].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(6)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(6)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(6)].end = size_eg;
}

action default_allocation_s6() {
    hdr.alloc[6].setValid();
    hdr.alloc[EG_STAGE_OFFSET(6)].setValid();
}

table allocation_6 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s6;
        default_allocation_s6;
    }
    //default_action = default_allocation_s6;
}

table instruction_7 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[7].opcode      : exact;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
		jump_s7;
		attempt_rejoin_s7;
		memory_read_s7;
		memory_write_s7;
		memory_increment_s7;
		memory_write_zero_s7;
		memory_minread_s7;
		memory_minreadinc_s7;
		hash_s7;
    }
    size = 512;
}

action get_allocation_s7(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[7].setValid();
    hdr.alloc[7].start = offset_ig;
    hdr.alloc[7].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(7)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(7)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(7)].end = size_eg;
}

action default_allocation_s7() {
    hdr.alloc[7].setValid();
    hdr.alloc[EG_STAGE_OFFSET(7)].setValid();
}

table allocation_7 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s7;
        default_allocation_s7;
    }
    //default_action = default_allocation_s7;
}

table instruction_8 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[8].opcode      : exact;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
		jump_s8;
		attempt_rejoin_s8;
		memory_read_s8;
		memory_write_s8;
		memory_increment_s8;
		memory_write_zero_s8;
		memory_minread_s8;
		memory_minreadinc_s8;
		hash_s8;
    }
    size = 512;
}

action get_allocation_s8(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[8].setValid();
    hdr.alloc[8].start = offset_ig;
    hdr.alloc[8].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(8)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(8)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(8)].end = size_eg;
}

action default_allocation_s8() {
    hdr.alloc[8].setValid();
    hdr.alloc[EG_STAGE_OFFSET(8)].setValid();
}

table allocation_8 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s8;
        default_allocation_s8;
    }
    //default_action = default_allocation_s8;
}

table instruction_9 {
    key = {
        hdr.meta.fid                            : range;
        hdr.instr[9].opcode      : exact;
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
		memfault;
		min_mbr1_mbr2;
		min_mbr2_mbr1;
		mbr1_equals_mbr2;
		copy_mar_mbr;
		copy_mbr_mar;
		copy_inc_mbr;
		copy_hash_data_mbr;
		bit_and_mar_mbr;
		mar_add_mbr;
		mar_add_mbr2;
		mbr_add_mbr2;
		mar_mbr_add_mbr2;
		not_mbr;
		mbr_or_mbr2;
		mbr_subtract_mbr2;
		swap_mbr_mbr2;
		max_mbr_mbr2;
		addr_mask_apply;
		addr_offset_apply;
		mar_load_d0;
		mar_load_d1;
		mar_load_d2;
		mar_load_d3;
		mbr_load_d0;
		d0_load_mbr;
		mbr_load_d1;
		d1_load_mbr;
		mbr_load_d2;
		d2_load_mbr;
		mbr_load_d3;
		d3_load_mbr;
		mbr2_load_d0;
		mbr2_load_d1;
		mbr2_load_d2;
		mbr2_load_d3;
		jump_s9;
		attempt_rejoin_s9;
		memory_read_s9;
		memory_write_s9;
		memory_increment_s9;
		memory_write_zero_s9;
		memory_minread_s9;
		memory_minreadinc_s9;
		hash_s9;
    }
    size = 512;
}

action get_allocation_s9(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[9].setValid();
    hdr.alloc[9].start = offset_ig;
    hdr.alloc[9].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(9)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(9)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(9)].end = size_eg;
}

action default_allocation_s9() {
    hdr.alloc[9].setValid();
    hdr.alloc[EG_STAGE_OFFSET(9)].setValid();
}

table allocation_9 {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s9;
        default_allocation_s9;
    }
    //default_action = default_allocation_s9;
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

    // control flow

    apply {
        hdr.meta.ig_timestamp = (bit<32>)ig_prsr_md.global_tstamp[31:0];
        hdr.meta.randnum = rnd.get();
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
        allocation_0.apply();
		allocation_1.apply();
		allocation_2.apply();
		allocation_3.apply();
		allocation_4.apply();
		allocation_5.apply();
		allocation_6.apply();
		allocation_7.apply();
		allocation_8.apply();
		allocation_9.apply();
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