action jump_s<stage-id>() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s<stage-id>() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[<instruction-id>].goto);
}

/*action memory_bulk_read_s<stage-id>() {
    hdr.bulk_data.data_<data-id> = heap_read_s<stage-id>.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

/*action memory_bulk_write_s<stage-id>() {
    heap_bulk_write_s<stage-id>.execute((bit<32>)hdr.meta.mar);
}*/

action memory_read_s<stage-id>() {
    hdr.meta.mbr2 = 0;
    hdr.meta.mbr = heap_conditional_increment_s<stage-id>.execute(hdr.meta.mar);
}

action memory_write_s<stage-id>() {
    hdr.meta.mbr2 = 0;
    hdr.meta.mbr = heap_write_s<stage-id>.execute(hdr.meta.mar);
}

action memory_eq_increment_s<stage-id>() {
    hdr.meta.mbr2 = 1;
    hdr.meta.mbr = heap_write_s<stage-id>.execute(hdr.meta.mar);
}

action memory_lt_increment_s<stage-id>() {
    hdr.meta.mbr = heap_conditional_increment_s<stage-id>.execute(hdr.meta.mar);
}

action memory_increment_s<stage-id>() {
    hdr.meta.mbr2 = 0xFFFF;
    hdr.meta.mbr = heap_conditional_increment_s<stage-id>.execute(hdr.meta.mar);
}

action hash_s<stage-id>() {
    //hdr.meta.mar = (bit<32>)crc_16_s<stage-id>.get({hdr.meta.mbr});
}