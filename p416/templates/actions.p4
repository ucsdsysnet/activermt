action mar_load_s<stage-id>() {
    meta.mar = hdr.instr[<instruction-id>].arg;
}

action mbr1_load_s<stage-id>() {
    meta.mbr = hdr.instr[<instruction-id>].arg;
}

action mbr2_load_s<stage-id>() {
    meta.mbr2 = hdr.instr[<instruction-id>].arg;
}

action mbr_add_s<stage-id>() {
    meta.mbr = meta.mbr + hdr.instr[<instruction-id>].arg;
}

action mar_add_s<stage-id>() {
    meta.mar = meta.mar + hdr.instr[<instruction-id>].arg;
}

action jump_s<stage-id>() {
    meta.disabled = 1;
    meta.pc = hdr.instr[<instruction-id>].goto;
}

action attempt_rejoin_s<stage-id>() {
    meta.disabled = (meta.pc ^ hdr.instr[<instruction-id>].goto);
}

action bit_and_mbr_s<stage-id>() {
    meta.mbr = meta.mbr & hdr.instr[<instruction-id>].arg;
}

action bit_and_mar_s<stage-id>() {
    meta.mar = meta.mar & hdr.instr[<instruction-id>].arg;
}

action mbr_equals_arg_s<stage-id>() {
    meta.mbr = meta.mbr ^ hdr.instr[<instruction-id>].arg;
}

action memory_read_s<stage-id>() {
    meta.mbr = heap_read_s<stage-id>.execute((bit<32>)meta.mar);
}

action memory_write_s<stage-id>() {
    heap_write_s<stage-id>.execute((bit<32>)meta.mar);
}