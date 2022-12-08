action jump_s<stage-id>() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s<stage-id>() {
    hdr.meta.disabled = (hdr.meta.disabled + hdr.instr[<instruction-id>].goto);
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
    // hdr.meta.mbr = 0;
    hdr.meta.mbr = heap_read_s<stage-id>.execute(hdr.meta.mar);
}

action memory_write_s<stage-id>() {
    heap_write_s<stage-id>.execute(hdr.meta.mar);
}

action memory_increment_s<stage-id>() {
    hdr.meta.mbr = heap_accumulate_s<stage-id>.execute(hdr.meta.mar);
}

/*action memory_write_max_s<stage-id>() {
    // TODO
    // hdr.meta.mbr = heap_conditional_rw_max_s<stage-id>.execute(hdr.meta.mar);
}*/

action memory_write_zero_s<stage-id>() {
    hdr.meta.mbr = heap_conditional_rw_zero_s<stage-id>.execute(hdr.meta.mar);
}

action memory_minread_s<stage-id>() {
    hdr.meta.mbr = heap_read_s<stage-id>.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

action memory_minreadinc_s<stage-id>() {
    hdr.meta.mbr = heap_accumulate_s<stage-id>.execute(hdr.meta.mar);
    hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}

/*action memory_minreadset_s<stage-id>() {
    hdr.meta.mbr = 1;
    // TODO
    // hdr.meta.mbr = heap_rw_s<stage-id>.execute(hdr.meta.mar);
    // hdr.meta.mbr2 = (hdr.meta.mbr2 < hdr.meta.mbr) ? hdr.meta.mbr2 : hdr.meta.mbr;
}*/

action hash_s<stage-id>() {
    hdr.meta.mar = (bit<32>)crc_16_s<stage-id>.get({
        hdr.meta.hash_data_0,
        hdr.meta.hash_data_1,
        hdr.meta.hash_data_2,
        hdr.meta.hash_data_3,
        hdr.meta.hash_data_4
    });
}