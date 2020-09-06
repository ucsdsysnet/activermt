action mar_load_1() {
    modify_field(meta.mar, ap[0].arg);
}

action mar_add_1() {
    add_to_field(meta.mar, ap[0].arg);
}

action mar_equals_1() {
    bit_xor(meta.mbr, meta.mar, ap[0].arg);
}

action mbr_load_1() {
    modify_field(meta.mbr, ap[0].arg);
}

action mbr_add_1() {
    add_to_field(meta.mbr, ap[0].arg);
}

action mbr_subtract_1() {
    subtract_from_field(meta.mbr, ap[0].arg);
}

action bit_and_mbr_mar_1() {
    bit_and(meta.mar, meta.mbr, ap[0].arg);
}

action mbr2_load_1() {
    modify_field(meta.mbr2, ap[0].arg);
}

action jump_1() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[0].goto);
}

action attempt_rejoin_1() {
    bit_xor(meta.disabled, meta.pc, ap[0].goto);
}

action bit_and_mbr_1() {
    bit_and(meta.mbr, meta.mbr, ap[0].arg);
}

field_list_calculation mar_list_hash_1 {
    input           { mar_list; }
    algorithm       : crc_16_en_13757;
    output_width    : 13;
}

action hashmar_1() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_1, 8192);
}

action mbr_equals_1() {
    bit_xor(meta.mbr, meta.mbr, ap[0].arg);
}

action mar_load_2() {
    modify_field(meta.mar, ap[1].arg);
}

action mar_add_2() {
    add_to_field(meta.mar, ap[1].arg);
}

action mar_equals_2() {
    bit_xor(meta.mbr, meta.mar, ap[1].arg);
}

action mbr_load_2() {
    modify_field(meta.mbr, ap[1].arg);
}

action mbr_add_2() {
    add_to_field(meta.mbr, ap[1].arg);
}

action mbr_subtract_2() {
    subtract_from_field(meta.mbr, ap[1].arg);
}

action bit_and_mbr_mar_2() {
    bit_and(meta.mar, meta.mbr, ap[1].arg);
}

action mbr2_load_2() {
    modify_field(meta.mbr2, ap[1].arg);
}

action jump_2() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[1].goto);
}

action attempt_rejoin_2() {
    bit_xor(meta.disabled, meta.pc, ap[1].goto);
}

action bit_and_mbr_2() {
    bit_and(meta.mbr, meta.mbr, ap[1].arg);
}

field_list_calculation mar_list_hash_2 {
    input           { mar_list; }
    algorithm       : crc_16_dds_110;
    output_width    : 13;
}

action hashmar_2() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_2, 8192);
}

action mbr_equals_2() {
    bit_xor(meta.mbr, meta.mbr, ap[1].arg);
}

action mar_load_3() {
    modify_field(meta.mar, ap[2].arg);
}

action mar_add_3() {
    add_to_field(meta.mar, ap[2].arg);
}

action mar_equals_3() {
    bit_xor(meta.mbr, meta.mar, ap[2].arg);
}

action mbr_load_3() {
    modify_field(meta.mbr, ap[2].arg);
}

action mbr_add_3() {
    add_to_field(meta.mbr, ap[2].arg);
}

action mbr_subtract_3() {
    subtract_from_field(meta.mbr, ap[2].arg);
}

action bit_and_mbr_mar_3() {
    bit_and(meta.mar, meta.mbr, ap[2].arg);
}

action mbr2_load_3() {
    modify_field(meta.mbr2, ap[2].arg);
}

action jump_3() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[2].goto);
}

action attempt_rejoin_3() {
    bit_xor(meta.disabled, meta.pc, ap[2].goto);
}

action bit_and_mbr_3() {
    bit_and(meta.mbr, meta.mbr, ap[2].arg);
}

field_list_calculation mar_list_hash_3 {
    input           { mar_list; }
    algorithm       : crc_16_dect;
    output_width    : 13;
}

action hashmar_3() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_3, 8192);
}

action mbr_equals_3() {
    bit_xor(meta.mbr, meta.mbr, ap[2].arg);
}

action mar_load_4() {
    modify_field(meta.mar, ap[3].arg);
}

action mar_add_4() {
    add_to_field(meta.mar, ap[3].arg);
}

action mar_equals_4() {
    bit_xor(meta.mbr, meta.mar, ap[3].arg);
}

action mbr_load_4() {
    modify_field(meta.mbr, ap[3].arg);
}

action mbr_add_4() {
    add_to_field(meta.mbr, ap[3].arg);
}

action mbr_subtract_4() {
    subtract_from_field(meta.mbr, ap[3].arg);
}

action bit_and_mbr_mar_4() {
    bit_and(meta.mar, meta.mbr, ap[3].arg);
}

action mbr2_load_4() {
    modify_field(meta.mbr2, ap[3].arg);
}

action jump_4() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[3].goto);
}

action attempt_rejoin_4() {
    bit_xor(meta.disabled, meta.pc, ap[3].goto);
}

action bit_and_mbr_4() {
    bit_and(meta.mbr, meta.mbr, ap[3].arg);
}

field_list_calculation mar_list_hash_4 {
    input           { mar_list; }
    algorithm       : crc_16_dnp;
    output_width    : 13;
}

action hashmar_4() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_4, 8192);
}

action mbr_equals_4() {
    bit_xor(meta.mbr, meta.mbr, ap[3].arg);
}

action mar_load_5() {
    modify_field(meta.mar, ap[4].arg);
}

action mar_add_5() {
    add_to_field(meta.mar, ap[4].arg);
}

action mar_equals_5() {
    bit_xor(meta.mbr, meta.mar, ap[4].arg);
}

action mbr_load_5() {
    modify_field(meta.mbr, ap[4].arg);
}

action mbr_add_5() {
    add_to_field(meta.mbr, ap[4].arg);
}

action mbr_subtract_5() {
    subtract_from_field(meta.mbr, ap[4].arg);
}

action bit_and_mbr_mar_5() {
    bit_and(meta.mar, meta.mbr, ap[4].arg);
}

action mbr2_load_5() {
    modify_field(meta.mbr2, ap[4].arg);
}

action jump_5() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[4].goto);
}

action attempt_rejoin_5() {
    bit_xor(meta.disabled, meta.pc, ap[4].goto);
}

action bit_and_mbr_5() {
    bit_and(meta.mbr, meta.mbr, ap[4].arg);
}

field_list_calculation mar_list_hash_5 {
    input           { mar_list; }
    algorithm       : crc_16_genibus;
    output_width    : 13;
}

action hashmar_5() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_5, 8192);
}

action mbr_equals_5() {
    bit_xor(meta.mbr, meta.mbr, ap[4].arg);
}

action mar_load_6() {
    modify_field(meta.mar, ap[5].arg);
}

action mar_add_6() {
    add_to_field(meta.mar, ap[5].arg);
}

action mar_equals_6() {
    bit_xor(meta.mbr, meta.mar, ap[5].arg);
}

action mbr_load_6() {
    modify_field(meta.mbr, ap[5].arg);
}

action mbr_add_6() {
    add_to_field(meta.mbr, ap[5].arg);
}

action mbr_subtract_6() {
    subtract_from_field(meta.mbr, ap[5].arg);
}

action bit_and_mbr_mar_6() {
    bit_and(meta.mar, meta.mbr, ap[5].arg);
}

action mbr2_load_6() {
    modify_field(meta.mbr2, ap[5].arg);
}

action jump_6() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[5].goto);
}

action attempt_rejoin_6() {
    bit_xor(meta.disabled, meta.pc, ap[5].goto);
}

action bit_and_mbr_6() {
    bit_and(meta.mbr, meta.mbr, ap[5].arg);
}

field_list_calculation mar_list_hash_6 {
    input           { mar_list; }
    algorithm       : crc_16_maxim;
    output_width    : 13;
}

action hashmar_6() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_6, 8192);
}

action mbr_equals_6() {
    bit_xor(meta.mbr, meta.mbr, ap[5].arg);
}

action mar_load_7() {
    modify_field(meta.mar, ap[6].arg);
}

action mar_add_7() {
    add_to_field(meta.mar, ap[6].arg);
}

action mar_equals_7() {
    bit_xor(meta.mbr, meta.mar, ap[6].arg);
}

action mbr_load_7() {
    modify_field(meta.mbr, ap[6].arg);
}

action mbr_add_7() {
    add_to_field(meta.mbr, ap[6].arg);
}

action mbr_subtract_7() {
    subtract_from_field(meta.mbr, ap[6].arg);
}

action bit_and_mbr_mar_7() {
    bit_and(meta.mar, meta.mbr, ap[6].arg);
}

action mbr2_load_7() {
    modify_field(meta.mbr2, ap[6].arg);
}

action jump_7() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[6].goto);
}

action attempt_rejoin_7() {
    bit_xor(meta.disabled, meta.pc, ap[6].goto);
}

action bit_and_mbr_7() {
    bit_and(meta.mbr, meta.mbr, ap[6].arg);
}

field_list_calculation mar_list_hash_7 {
    input           { mar_list; }
    algorithm       : crc_16_riello;
    output_width    : 13;
}

action hashmar_7() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_7, 8192);
}

action mbr_equals_7() {
    bit_xor(meta.mbr, meta.mbr, ap[6].arg);
}

action mar_load_8() {
    modify_field(meta.mar, ap[7].arg);
}

action mar_add_8() {
    add_to_field(meta.mar, ap[7].arg);
}

action mar_equals_8() {
    bit_xor(meta.mbr, meta.mar, ap[7].arg);
}

action mbr_load_8() {
    modify_field(meta.mbr, ap[7].arg);
}

action mbr_add_8() {
    add_to_field(meta.mbr, ap[7].arg);
}

action mbr_subtract_8() {
    subtract_from_field(meta.mbr, ap[7].arg);
}

action bit_and_mbr_mar_8() {
    bit_and(meta.mar, meta.mbr, ap[7].arg);
}

action mbr2_load_8() {
    modify_field(meta.mbr2, ap[7].arg);
}

action jump_8() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[7].goto);
}

action attempt_rejoin_8() {
    bit_xor(meta.disabled, meta.pc, ap[7].goto);
}

action bit_and_mbr_8() {
    bit_and(meta.mbr, meta.mbr, ap[7].arg);
}

field_list_calculation mar_list_hash_8 {
    input           { mar_list; }
    algorithm       : crc_16_usb;
    output_width    : 13;
}

action hashmar_8() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_8, 8192);
}

action mbr_equals_8() {
    bit_xor(meta.mbr, meta.mbr, ap[7].arg);
}

action mar_load_9() {
    modify_field(meta.mar, ap[8].arg);
}

action mar_add_9() {
    add_to_field(meta.mar, ap[8].arg);
}

action mar_equals_9() {
    bit_xor(meta.mbr, meta.mar, ap[8].arg);
}

action mbr_load_9() {
    modify_field(meta.mbr, ap[8].arg);
}

action mbr_add_9() {
    add_to_field(meta.mbr, ap[8].arg);
}

action mbr_subtract_9() {
    subtract_from_field(meta.mbr, ap[8].arg);
}

action bit_and_mbr_mar_9() {
    bit_and(meta.mar, meta.mbr, ap[8].arg);
}

action mbr2_load_9() {
    modify_field(meta.mbr2, ap[8].arg);
}

action jump_9() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[8].goto);
}

action attempt_rejoin_9() {
    bit_xor(meta.disabled, meta.pc, ap[8].goto);
}

action bit_and_mbr_9() {
    bit_and(meta.mbr, meta.mbr, ap[8].arg);
}

field_list_calculation mar_list_hash_9 {
    input           { mar_list; }
    algorithm       : crc_16_teledisk;
    output_width    : 13;
}

action hashmar_9() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_9, 8192);
}

action mbr_equals_9() {
    bit_xor(meta.mbr, meta.mbr, ap[8].arg);
}

action mar_load_10() {
    modify_field(meta.mar, ap[9].arg);
}

action mar_add_10() {
    add_to_field(meta.mar, ap[9].arg);
}

action mar_equals_10() {
    bit_xor(meta.mbr, meta.mar, ap[9].arg);
}

action mbr_load_10() {
    modify_field(meta.mbr, ap[9].arg);
}

action mbr_add_10() {
    add_to_field(meta.mbr, ap[9].arg);
}

action mbr_subtract_10() {
    subtract_from_field(meta.mbr, ap[9].arg);
}

action bit_and_mbr_mar_10() {
    bit_and(meta.mar, meta.mbr, ap[9].arg);
}

action mbr2_load_10() {
    modify_field(meta.mbr2, ap[9].arg);
}

action jump_10() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[9].goto);
}

action attempt_rejoin_10() {
    bit_xor(meta.disabled, meta.pc, ap[9].goto);
}

action bit_and_mbr_10() {
    bit_and(meta.mbr, meta.mbr, ap[9].arg);
}

field_list_calculation mar_list_hash_10 {
    input           { mar_list; }
    algorithm       : crc_16_mcrf4xx;
    output_width    : 13;
}

action hashmar_10() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_10, 8192);
}

action mbr_equals_10() {
    bit_xor(meta.mbr, meta.mbr, ap[9].arg);
}

action mar_load_11() {
    modify_field(meta.mar, ap[10].arg);
}

action mar_add_11() {
    add_to_field(meta.mar, ap[10].arg);
}

action mar_equals_11() {
    bit_xor(meta.mbr, meta.mar, ap[10].arg);
}

action mbr_load_11() {
    modify_field(meta.mbr, ap[10].arg);
}

action mbr_add_11() {
    add_to_field(meta.mbr, ap[10].arg);
}

action mbr_subtract_11() {
    subtract_from_field(meta.mbr, ap[10].arg);
}

action bit_and_mbr_mar_11() {
    bit_and(meta.mar, meta.mbr, ap[10].arg);
}

action mbr2_load_11() {
    modify_field(meta.mbr2, ap[10].arg);
}

action jump_11() {
    bit_or(meta.disabled, meta.disabled, 2);
    modify_field(meta.pc, ap[10].goto);
}

action attempt_rejoin_11() {
    bit_xor(meta.disabled, meta.pc, ap[10].goto);
}

action bit_and_mbr_11() {
    bit_and(meta.mbr, meta.mbr, ap[10].arg);
}

field_list_calculation mar_list_hash_11 {
    input           { mar_list; }
    algorithm       : crc_16_t10_dif;
    output_width    : 13;
}

action hashmar_11() {
    modify_field_with_hash_based_offset(meta.mar, 0, mar_list_hash_11, 8192);
}

action mbr_equals_11() {
    bit_xor(meta.mbr, meta.mbr, ap[10].arg);
}