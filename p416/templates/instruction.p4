table instruction_<stage-id> {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[<instruction-id>].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        //hdr.meta.zero                           : exact;
        hdr.meta.mbr[19:0]                      : range;
        hdr.meta.mar[19:0]                      : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        fetch_queue;
        fetch_qdelay;
        fetch_pktcount;
        <generated-actions>
    }
    size = 512;
}

action get_allocation_s<stage-id>(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[<instruction-id>].offset = offset_ig;
    hdr.alloc[<instruction-id>].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].offset = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].size = size_eg;
}

table allocation_<stage-id> {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s<stage-id>;
    }
}