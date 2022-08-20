action get_allocation_s<stage-id>(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[<instruction-id>].setValid();
    hdr.alloc[<instruction-id>].offset = offset_ig;
    hdr.alloc[<instruction-id>].size = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].setValid();
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