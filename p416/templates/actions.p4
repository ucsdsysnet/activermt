action mar_load_s<stage-id>() {
    hdr.meta.mar = hdr.instr[<instruction-id>].arg;
}

action mbr1_load_s<stage-id>() {
    hdr.meta.mbr = hdr.instr[<instruction-id>].arg;
}

action mbr2_load_s<stage-id>() {
    hdr.meta.mbr2 = hdr.instr[<instruction-id>].arg;
}

action mbr_add_s<stage-id>() {
    hdr.meta.mbr = hdr.meta.mbr + hdr.instr[<instruction-id>].arg;
}

action mar_add_s<stage-id>() {
    hdr.meta.mar = hdr.meta.mar + hdr.instr[<instruction-id>].arg;
}

action jump_s<stage-id>() {
    hdr.meta.disabled = 1;
}

action attempt_rejoin_s<stage-id>() {
    hdr.meta.disabled = (hdr.meta.disabled ^ hdr.instr[<instruction-id>].goto);
}

action bit_and_mbr_s<stage-id>() {
    hdr.meta.mbr = hdr.meta.mbr & hdr.instr[<instruction-id>].arg;
}

action bit_and_mar_s<stage-id>() {
    hdr.meta.mar = hdr.meta.mar & hdr.instr[<instruction-id>].arg;
}

action mbr_equals_arg_s<stage-id>() {
    hdr.meta.mbr = hdr.meta.mbr ^ hdr.instr[<instruction-id>].arg;
}

action memory_read_s<stage-id>() {
    hdr.meta.mbr = heap_read_s<stage-id>.execute((bit<32>)hdr.meta.mar);
}

action memory_write_s<stage-id>() {
    heap_write_s<stage-id>.execute((bit<32>)hdr.meta.mar);
}

action memory_count_s<stage-id>() {
    hdr.meta.mbr = heap_count_s<stage-id>.execute((bit<32>)hdr.meta.mar);
}

action hash_s<stage-id>() {
    hdr.meta.mar = crc_16_s<stage-id>.get({hdr.meta.mbr});
}