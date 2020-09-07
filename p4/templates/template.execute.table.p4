table execute_# {
    reads {
        ap[?].opcode        : exact;
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
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_#;
        mar_load_#;
        mbr_load_#;
        mbr2_load_#;
        mbr_add_#;
        mar_add_#;
        //mbr_subtract_#;
        //bit_and_mbr_mar_#;
        #memory
        memory_#_reset;
        jump_#;
        attempt_rejoin_#;
        //mar_equals_#;
        bit_and_mbr_#;
        bit_and_mar_#;
        counter_#_rmw;
        mbr_equals_#;
    }
}