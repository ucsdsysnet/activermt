action get_allocation_s<stage-id>(bit<16> offset_ig, bit<16> size_ig, bit<16> offset_eg, bit<16> size_eg) {
    hdr.alloc[<instruction-id>].setValid();
    hdr.alloc[<instruction-id>].start = offset_ig;
    hdr.alloc[<instruction-id>].end = size_ig;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].setValid();
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].start = offset_eg;
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].end = size_eg;
}

action default_allocation_s<stage-id>() {
    hdr.alloc[<instruction-id>].setValid();
    hdr.alloc[EG_STAGE_OFFSET(<instruction-id>)].setValid();
}

table allocation_<stage-id> {
    key = {
        hdr.ih.fid              : exact;
        hdr.ih.flag_allocated   : exact;
    }
    actions = {
        get_allocation_s<stage-id>;
        default_allocation_s<stage-id>;
    }
    //default_action = default_allocation_s<stage-id>;
}