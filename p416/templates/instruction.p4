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