action <reg>_load_d<data-id>() {
    hdr.meta.<reg> = hdr.data.<data>;
}

action d<data-id>_load_<reg>() {
    hdr.data.<data> = hdr.meta.<reg>;
}

/*action addrmap_load_d<data-id>() {
    hdr.meta.paddr_mask = hdr.data.<data>;
    hdr.meta.paddr_offset = hdr.data.<data> >> 16;
}*/