/*action <reg>_load_d<data-id>() {
    hdr.meta.<reg> = hdr.data.<data>;
}*/

/*action d<data-id>_load_<reg>() {
    hdr.data.<data> = hdr.meta.<reg>;
}*/

action mar_load_d<data-id>() {
    hdr.meta.mar = hdr.data.<data> & 0xFFFFF;
}

action mbr_load_d<data-id>() {
    hdr.meta.mbr = hdr.data.<data>;
}

action mbr2_load_d<data-id>() {
    hdr.meta.mbr2 = hdr.data.<data>;
}

action d<data-id>_load_mbr() {
    hdr.data.<data> = hdr.meta.mbr;
}

/*action addrmap_load_d<data-id>() {
    hdr.meta.paddr_mask = hdr.data.<data>;
    hdr.meta.paddr_offset = hdr.data.<data> >> 16;
}*/