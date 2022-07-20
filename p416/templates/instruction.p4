table instruction_<stage-id> {
    key = {
        hdr.ih.fid                              : exact;
        hdr.instr[<instruction-id>].opcode      : exact;
        hdr.meta.complete                       : exact;
        hdr.meta.disabled                       : exact;
        //hdr.meta.zero                           : exact;
        hdr.meta.mbr                            : range;
        hdr.meta.mar                            : range;
    }
    actions = {
        drop;
        mark_termination;
        skip;
        rts;
        set_port;
        load_5_tuple_tcp;
        <generated-actions>
    }
    size = 512;
}