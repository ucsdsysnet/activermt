action <reg>_load_d<data-id>() {
    hdr.meta.<reg> = hdr.data.<data>;
}

action d<data-id>_load_<reg>() {
    hdr.data.<data> = hdr.meta.<reg>;
}

/*action <reg>_add_d<data-id>() {
    hdr.meta.<reg> = hdr.meta.<reg> + hdr.data.<data>;
}*/

/*action bit_and_<reg>_d<data-id>() {
    hdr.meta.<reg> = hdr.meta.<reg> & hdr.data.<data>;
}*/

/*action <reg>_equals_d<data-id>() {
    hdr.meta.<reg> = hdr.meta.<reg> ^ hdr.data.<data>;
}*/