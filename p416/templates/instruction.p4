table instruction_<stage-id> {
    key = {
        hdr.ih.fid              : exact;
        hdr.instr[<instruction-id>].opcode     : exact;
        meta.complete           : exact;
        meta.disabled           : exact;
        meta.mbr                : range;
        meta.mar                : range;
    }
    actions = {
        drop;
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
        copy_acc_mbr;
        <generated-actions>
    }
}

// create a set of parallel tables for mutually exclusive actions