action mar_load_#() {
    modify_field(meta.mar, ap[?].arg);
}

action mar_add_#() {
    add_to_field(meta.mar, ap[?].arg);
}

action mbr_load_#() {
    modify_field(meta.mbr, ap[?].arg);
}

action mbr_add_#() {
    add_to_field(meta.mbr, ap[?].arg);
}

action mbr2_load_#() {
    modify_field(meta.mbr2, ap[?].arg);
}

action jump_#() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[?].goto);
}

action attempt_rejoin_#() {
    bit_xor(meta.disabled, meta.pc, ap[?].goto);
}

action bit_and_mbr_#() {
    bit_and(meta.mbr, meta.mbr, ap[?].arg);
}

action bit_and_mar_#() {
    bit_and(meta.mar, meta.mar, ap[?].arg);
}

field_list_calculation mar_list_hash_# {
    input           { mar_list; }
    algorithm       : crc_16_$;
    output_width    : 13;
}

action hashmar_#() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_#, 8192);
}

action mbr_equals_#() {
    bit_xor(meta.mbr, meta.mbr, ap[?].arg);
}

/*action bit_and_mbr_mar_#() {
    bit_and(meta.mar, meta.mbr, ap[?].arg);
}

action mbr_subtract_#() {
    subtract_from_field(meta.mbr, ap[?].arg);
}

action mar_equals_#() {
    bit_xor(meta.mbr, meta.mar, ap[?].arg);
}*/