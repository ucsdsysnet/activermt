table instruction_<stage-id> {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[<instruction-id>].opcode      : exact;
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
        <generated-actions>
    }
}