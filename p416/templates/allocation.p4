action get_allocation_s<stage-id>(bit<32> offset, bit<32> size) {
    hdr.alloc[<instruction-id>].offset = offset;
    hdr.alloc[<instruction-id>].size = size;
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