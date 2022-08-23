action <reg>_load_d<data-id>() {
    hdr.meta.<reg> = hdr.data.<data>;
}

action d<data-id>_load_<reg>() {
    hdr.data.<data> = hdr.meta.<reg>;
}