action jump_s<stage-id>() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s<stage-id>() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[<instruction-id>].goto);
}

action memory_read_s<stage-id>() {
    hdr.meta.mbr = heap_read_s<stage-id>.execute(hdr.meta.mar);
}

/*action memory_bulk_read_s<stage-id>() {
    hdr.bulk_data.data_<data-id> = heap_read_s<stage-id>.execute((bit<32>)hdr.meta.mar);
    hdr.bulk_data.setValid();
    hdr.ih.opt_data = 1;
}*/

action memory_write_s<stage-id>() {
    heap_write_s<stage-id>.execute(hdr.meta.mar);
}

action memory_conditional_write_s<stage-id>() {
    heap_conditional_write_s<stage-id>.execute(hdr.meta.mar);
}

/*action memory_bulk_write_s<stage-id>() {
    heap_bulk_write_s<stage-id>.execute((bit<32>)hdr.meta.mar);
}*/

action memory_count_s<stage-id>() {
    hdr.meta.mbr = heap_count_s<stage-id>.execute(hdr.meta.mar);
}

action hash_s<stage-id>() {
    //hdr.meta.mar = (bit<32>)crc_16_s<stage-id>.get({hdr.meta.mbr});
}