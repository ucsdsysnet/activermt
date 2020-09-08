table execute_1 {
    reads {
        ap[0].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_1;
        mar_load_1;
        mbr_load_1;
        mbr2_load_1;
        mbr_add_1;
        mar_add_1;
        //mbr_subtract_1;
        //bit_and_mbr_mar_1;
        memory_1_read;
		memory_1_write;
        //memory_1_reset;
        jump_1;
        attempt_rejoin_1;
        //mar_equals_1;
        bit_and_mbr_1;
        bit_and_mar_1;
        counter_1_rmw;
        mbr_equals_1;
        memory_1_sub;
    }
}

table execute_2 {
    reads {
        ap[1].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_2;
        mar_load_2;
        mbr_load_2;
        mbr2_load_2;
        mbr_add_2;
        mar_add_2;
        //mbr_subtract_2;
        //bit_and_mbr_mar_2;
        memory_2_read;
		memory_2_write;
        //memory_2_reset;
        jump_2;
        attempt_rejoin_2;
        //mar_equals_2;
        bit_and_mbr_2;
        bit_and_mar_2;
        counter_2_rmw;
        mbr_equals_2;
        memory_2_sub;
    }
}

table execute_3 {
    reads {
        ap[2].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_3;
        mar_load_3;
        mbr_load_3;
        mbr2_load_3;
        mbr_add_3;
        mar_add_3;
        //mbr_subtract_3;
        //bit_and_mbr_mar_3;
        memory_3_read;
		memory_3_write;
        //memory_3_reset;
        jump_3;
        attempt_rejoin_3;
        //mar_equals_3;
        bit_and_mbr_3;
        bit_and_mar_3;
        counter_3_rmw;
        mbr_equals_3;
        memory_3_sub;
    }
}

table execute_4 {
    reads {
        ap[3].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_4;
        mar_load_4;
        mbr_load_4;
        mbr2_load_4;
        mbr_add_4;
        mar_add_4;
        //mbr_subtract_4;
        //bit_and_mbr_mar_4;
        memory_4_read;
		memory_4_write;
        //memory_4_reset;
        jump_4;
        attempt_rejoin_4;
        //mar_equals_4;
        bit_and_mbr_4;
        bit_and_mar_4;
        counter_4_rmw;
        mbr_equals_4;
        memory_4_sub;
    }
}

table execute_5 {
    reads {
        ap[4].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_5;
        mar_load_5;
        mbr_load_5;
        mbr2_load_5;
        mbr_add_5;
        mar_add_5;
        //mbr_subtract_5;
        //bit_and_mbr_mar_5;
        memory_5_read;
		memory_5_write;
        //memory_5_reset;
        jump_5;
        attempt_rejoin_5;
        //mar_equals_5;
        bit_and_mbr_5;
        bit_and_mar_5;
        counter_5_rmw;
        mbr_equals_5;
        memory_5_sub;
    }
}

table execute_6 {
    reads {
        ap[5].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_6;
        mar_load_6;
        mbr_load_6;
        mbr2_load_6;
        mbr_add_6;
        mar_add_6;
        //mbr_subtract_6;
        //bit_and_mbr_mar_6;
        memory_6_read;
		memory_6_write;
        //memory_6_reset;
        jump_6;
        attempt_rejoin_6;
        //mar_equals_6;
        bit_and_mbr_6;
        bit_and_mar_6;
        counter_6_rmw;
        mbr_equals_6;
        memory_6_sub;
    }
}

table execute_7 {
    reads {
        ap[6].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_7;
        mar_load_7;
        mbr_load_7;
        mbr2_load_7;
        mbr_add_7;
        mar_add_7;
        //mbr_subtract_7;
        //bit_and_mbr_mar_7;
        memory_7_read;
		memory_7_write;
        //memory_7_reset;
        jump_7;
        attempt_rejoin_7;
        //mar_equals_7;
        bit_and_mbr_7;
        bit_and_mar_7;
        counter_7_rmw;
        mbr_equals_7;
        memory_7_sub;
    }
}

table execute_8 {
    reads {
        ap[7].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_8;
        mar_load_8;
        mbr_load_8;
        mbr2_load_8;
        mbr_add_8;
        mar_add_8;
        //mbr_subtract_8;
        //bit_and_mbr_mar_8;
        memory_8_read;
		memory_8_write;
        //memory_8_reset;
        jump_8;
        attempt_rejoin_8;
        //mar_equals_8;
        bit_and_mbr_8;
        bit_and_mar_8;
        counter_8_rmw;
        mbr_equals_8;
        memory_8_sub;
    }
}

table execute_9 {
    reads {
        ap[8].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_9;
        mar_load_9;
        mbr_load_9;
        mbr2_load_9;
        mbr_add_9;
        mar_add_9;
        //mbr_subtract_9;
        //bit_and_mbr_mar_9;
        memory_9_read;
		memory_9_write;
        //memory_9_reset;
        jump_9;
        attempt_rejoin_9;
        //mar_equals_9;
        bit_and_mbr_9;
        bit_and_mar_9;
        counter_9_rmw;
        mbr_equals_9;
        memory_9_sub;
    }
}

table execute_10 {
    reads {
        ap[9].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_10;
        mar_load_10;
        mbr_load_10;
        mbr2_load_10;
        mbr_add_10;
        mar_add_10;
        //mbr_subtract_10;
        //bit_and_mbr_mar_10;
        memory_10_read;
		memory_10_write;
        //memory_10_reset;
        jump_10;
        attempt_rejoin_10;
        //mar_equals_10;
        bit_and_mbr_10;
        bit_and_mar_10;
        counter_10_rmw;
        mbr_equals_10;
        memory_10_sub;
    }
}

table execute_11 {
    reads {
        ap[10].opcode        : exact;
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
    }
    actions {
// ==== GENERIC ACTIONS ==== //  
        skip;
        complete;
        cancel_complete;
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        hash_generic;
        load_hashlist_ipv4src;
        load_hashlist_ipv4dst;
        load_hashlist_ipv4proto;
        load_hashlist_udpsrcport;
        load_hashlist_udpdstport;
        load_hashlist_5tuple;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_11;
        mar_load_11;
        mbr_load_11;
        mbr2_load_11;
        mbr_add_11;
        mar_add_11;
        //mbr_subtract_11;
        //bit_and_mbr_mar_11;
        memory_11_read;
		memory_11_write;
        //memory_11_reset;
        jump_11;
        attempt_rejoin_11;
        //mar_equals_11;
        bit_and_mbr_11;
        bit_and_mar_11;
        counter_11_rmw;
        mbr_equals_11;
        memory_11_sub;
    }
}