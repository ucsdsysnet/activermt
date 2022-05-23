table cached_# {
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
        hashmar_#;
        counter_#_rmw;
        memory_#_read;
        memory_#_write;
        memory_#_sub;
    }
}