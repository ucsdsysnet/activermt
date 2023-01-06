/*action uncomplete() {
    hdr.meta.complete = 0;
}*/

action fork() {
    hdr.meta.duplicate = 1;
}

action copy_mbr2_mbr1() {
    hdr.meta.mbr2 = hdr.meta.mbr;
}

action copy_mbr1_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr2;
}

/*action mark_packet() {
    hdr.ih.flag_marked = 1;
}*/

action memfault() {
    hdr.ih.flag_mfault = 1;
    complete();
    rts();
}

action min_mbr1_mbr2() {
    hdr.meta.mbr = (hdr.meta.mbr <= hdr.meta.mbr2 ? hdr.meta.mbr : hdr.meta.mbr2);
}

action min_mbr2_mbr1() {
    hdr.meta.mbr2 = (hdr.meta.mbr2 <= hdr.meta.mbr ? hdr.meta.mbr2 : hdr.meta.mbr);
}

action mbr1_equals_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.meta.mbr2;
}

action copy_mar_mbr() {
    hdr.meta.mar = hdr.meta.mbr;
}

action copy_mbr_mar() {
    hdr.meta.mbr = hdr.meta.mar;
}

action copy_inc_mbr() {
    hdr.meta.inc = hdr.meta.mbr;
}

action copy_hash_data_mbr() {
    hdr.meta.hash_data_0 = hdr.meta.mbr;
}

action bit_and_mar_mbr() {
    hdr.meta.mar = hdr.meta.mar & hdr.meta.mbr;
}

action mar_add_mbr() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr;
}

action mar_add_mbr2() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.mbr2;
}

action mbr_add_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.meta.mbr2;
}

action mar_mbr_add_mbr2() {
    hdr.meta.mar = hdr.meta.mbr + hdr.meta.mbr2;
}

/*action load_salt() {
    hdr.meta.mbr = CONST_SALT;
}*/

action not_mbr() {
    hdr.meta.mbr = ~hdr.meta.mbr;
}

action mbr_or_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr | hdr.meta.mbr2;
}

action mbr_subtract_mbr2() {
    hdr.meta.mbr = hdr.meta.mbr - hdr.meta.mbr2;
}

action swap_mbr_mbr2() {
    bit<32> tmp;
    tmp = hdr.meta.mbr;
    hdr.meta.mbr = hdr.meta.mbr2;
    hdr.meta.mbr2 = tmp;
}

action max_mbr_mbr2() {
    hdr.meta.mbr = (hdr.meta.mbr >= hdr.meta.mbr2 ? hdr.meta.mbr : hdr.meta.mbr2);
}

/*action addr_mask_apply() {
    hdr.meta.mar = hdr.meta.mar & hdr.meta.paddr_mask;
}*/

/*action addr_offset_apply() {
    hdr.meta.mar = hdr.meta.mar + hdr.meta.paddr_offset;
}*/

action addr_mask_apply(bit<32> addr_mask) {
    hdr.meta.mar = hdr.meta.mar & addr_mask;
}

action addr_offset_apply(bit<32> offset) {
    hdr.meta.mar = hdr.meta.mar + offset;
}