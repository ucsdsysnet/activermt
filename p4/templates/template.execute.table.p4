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
        loop_init;
        loop_end;
        acc_load;
        acc2_load;
        copy_mbr2_mbr;
        copy_mbr_mbr2;
        mark_processed_packet;
        unmark_processed_packet;
        drop;
        cancel_drop;
        duplicate;
        enable_execution;
        return_to_sender;
        memfault;
        //hash5tuple;
        set_port;
        get_random_port;
        //hash_id;
        goto_aux;
        min_mbr_mbr2;
// ==== STAGE SPECIFIC ACTIONS ==== //        
        hashmar_#;
        mar_load_#;
        mbr_load_#;
        mbr2_load_#;
        mbr_add_#;
        mar_add_#;
        mbr_subtract_#;
        bit_and_mbr_mar_#;
        #memory
        memory_#_reset;
        jump_#;
        attempt_rejoin_#;
        mar_equals_#;
        bit_and_mbr_#;
        counter_#_rmw;
    }
}