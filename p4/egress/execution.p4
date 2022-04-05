table execute_1 {
    reads {
        ap[0].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_1;
        mar_load_1;
        mbr_load_1;
        mbr2_load_1;
        mbr_add_1;
        mar_add_1;
        jump_1;
        attempt_rejoin_1;
        bit_and_mbr_1;
        bit_and_mar_1;
        mbr_equals_1;
        counter_1_rmw;
        memory_1_read;
        memory_1_write;
        memory_1_sub;
    }
}

table cached_1 {
    reads {
        as.flag_usecache    : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_1;
        counter_1_rmw;
        memory_1_read;
        memory_1_write;
        memory_1_sub;
    }
}

table execute_2 {
    reads {
        ap[1].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_2;
        mar_load_2;
        mbr_load_2;
        mbr2_load_2;
        mbr_add_2;
        mar_add_2;
        jump_2;
        attempt_rejoin_2;
        bit_and_mbr_2;
        bit_and_mar_2;
        mbr_equals_2;
        counter_2_rmw;
        memory_2_read;
        memory_2_write;
        memory_2_sub;
    }
}

table cached_2 {
    reads {
        as.flag_usecache    : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_2;
        counter_2_rmw;
        memory_2_read;
        memory_2_write;
        memory_2_sub;
    }
}

table execute_3 {
    reads {
        ap[2].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_3;
        mar_load_3;
        mbr_load_3;
        mbr2_load_3;
        mbr_add_3;
        mar_add_3;
        jump_3;
        attempt_rejoin_3;
        bit_and_mbr_3;
        bit_and_mar_3;
        mbr_equals_3;
        counter_3_rmw;
        memory_3_read;
        memory_3_write;
        memory_3_sub;
    }
}

table cached_3 {
    reads {
        as.flag_usecache    : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_3;
        counter_3_rmw;
        memory_3_read;
        memory_3_write;
        memory_3_sub;
    }
}

table execute_4 {
    reads {
        ap[3].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_4;
        mar_load_4;
        mbr_load_4;
        mbr2_load_4;
        mbr_add_4;
        mar_add_4;
        jump_4;
        attempt_rejoin_4;
        bit_and_mbr_4;
        bit_and_mar_4;
        mbr_equals_4;
        counter_4_rmw;
        memory_4_read;
        memory_4_write;
        memory_4_sub;
    }
}

table cached_4 {
    reads {
        as.flag_usecache    : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_ig;
        //cancel_drop;
        //duplicate;
        enable_execution;
        //swap_addr;
        rts_addr;
        memfault;
        //set_port;
        goto_aux;
        min_mbr_mbr2;
        min_mbr2_mbr;
        mbr_equals_mbr2;
        copy_mar_mbr;
        copy_mbr_mar;
        bit_and_mar_mbr;
        mar_add_mbr;
        acc_to_mbr;
        hash_acc2;
        
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_4;
        counter_4_rmw;
        memory_4_read;
        memory_4_write;
        memory_4_sub;
    }
}

table execute_5 {
    reads {
        ap[0].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_5;
        mar_load_5;
        mbr_load_5;
        mbr2_load_5;
        mbr_add_5;
        mar_add_5;
        //mbr_subtract_5;
        //bit_and_mbr_mar_5;
        jump_5;
        attempt_rejoin_5;
        //mar_equals_5;
        bit_and_mbr_5;
        bit_and_mar_5;
        mbr_equals_5;
        counter_5_rmw;
        memory_5_read;
        memory_5_write;
        memory_5_sub;
    }
}

table precache_5 {
    reads {
        as.flag_precache    : exact;
    }
    actions {
        write_prog_5;
    }
}

table cached_5 {
    reads {
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        as.flag_usecache    : exact;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //
        hashmar_5;
        //mar_load_5;
        //mbr_load_5;
        //mbr2_load_5;
        //mbr_add_5;
        //mar_add_5;
        //jump_5;
        //attempt_rejoin_5;
        //bit_and_mbr_5;
        //bit_and_mar_5;
        counter_5_rmw;
        memory_5_read;
        memory_5_write;
        memory_5_sub;
    }
}

table execute_6 {
    reads {
        ap[1].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_6;
        mar_load_6;
        mbr_load_6;
        mbr2_load_6;
        mbr_add_6;
        mar_add_6;
        //mbr_subtract_6;
        //bit_and_mbr_mar_6;
        jump_6;
        attempt_rejoin_6;
        //mar_equals_6;
        bit_and_mbr_6;
        bit_and_mar_6;
        mbr_equals_6;
        counter_6_rmw;
        memory_6_read;
        memory_6_write;
        memory_6_sub;
    }
}

table precache_6 {
    reads {
        as.flag_precache    : exact;
    }
    actions {
        write_prog_6;
    }
}

table cached_6 {
    reads {
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        as.flag_usecache    : exact;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //
        hashmar_6;
        //mar_load_6;
        //mbr_load_6;
        //mbr2_load_6;
        //mbr_add_6;
        //mar_add_6;
        //jump_6;
        //attempt_rejoin_6;
        //bit_and_mbr_6;
        //bit_and_mar_6;
        counter_6_rmw;
        memory_6_read;
        memory_6_write;
        memory_6_sub;
    }
}

table execute_7 {
    reads {
        ap[2].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_7;
        mar_load_7;
        mbr_load_7;
        mbr2_load_7;
        mbr_add_7;
        mar_add_7;
        //mbr_subtract_7;
        //bit_and_mbr_mar_7;
        jump_7;
        attempt_rejoin_7;
        //mar_equals_7;
        bit_and_mbr_7;
        bit_and_mar_7;
        mbr_equals_7;
        counter_7_rmw;
        memory_7_read;
        memory_7_write;
        memory_7_sub;
    }
}

table precache_7 {
    reads {
        as.flag_precache    : exact;
    }
    actions {
        write_prog_7;
    }
}

table cached_7 {
    reads {
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        as.flag_usecache    : exact;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //
        hashmar_7;
        //mar_load_7;
        //mbr_load_7;
        //mbr2_load_7;
        //mbr_add_7;
        //mar_add_7;
        //jump_7;
        //attempt_rejoin_7;
        //bit_and_mbr_7;
        //bit_and_mar_7;
        counter_7_rmw;
        memory_7_read;
        memory_7_write;
        memory_7_sub;
    }
}

table execute_8 {
    reads {
        ap[3].opcode        : exact;
        as.fid              : exact;
        meta.complete       : exact;
        meta.disabled       : exact;
        meta.mbr            : range;
        meta.mar            : range;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_8;
        mar_load_8;
        mbr_load_8;
        mbr2_load_8;
        mbr_add_8;
        mar_add_8;
        //mbr_subtract_8;
        //bit_and_mbr_mar_8;
        jump_8;
        attempt_rejoin_8;
        //mar_equals_8;
        bit_and_mbr_8;
        bit_and_mar_8;
        mbr_equals_8;
        counter_8_rmw;
        memory_8_read;
        memory_8_write;
        memory_8_sub;
    }
}

table precache_8 {
    reads {
        as.flag_precache    : exact;
    }
    actions {
        write_prog_8;
    }
}

table cached_8 {
    reads {
        meta.complete       : exact;
        meta.disabled       : range;
        meta.mbr            : range;
        meta.quota_start    : range;
        meta.quota_end      : range;
        meta.mar            : range;
        as.fid              : exact;
        as.flag_usecache    : exact;
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
        drop_eg;
        cancel_drop_eg;
        duplicate;
        enable_execution;
        return_to_sender;
        //swap_addr;
        rts_addr;
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
        acc_to_mbr;
        set_port_ig;
// ==== STAGE SPECIFIC ACTIONS ==== //
        hashmar_8;
        //mar_load_8;
        //mbr_load_8;
        //mbr2_load_8;
        //mbr_add_8;
        //mar_add_8;
        //jump_8;
        //attempt_rejoin_8;
        //bit_and_mbr_8;
        //bit_and_mar_8;
        counter_8_rmw;
        memory_8_read;
        memory_8_write;
        memory_8_sub;
    }
}