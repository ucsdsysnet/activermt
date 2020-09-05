action skip() {}

action drop() {
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
} 

action cancel_drop() {
    bit_and(eg_intr_md_for_oport.drop_ctl, eg_intr_md_for_oport.drop_ctl, 6);
}

action duplicate() {
    modify_field(meta.duplicate, 1);
}

action loop_init() {
    modify_field(meta.loop, 1);
}

action loop_end() {
    modify_field(meta.loop, 0);
}

action complete() {
    modify_field(meta.complete, 1);
    modify_field(as.flag_done, 1);
}

action copy_mbr2_mbr() {
    modify_field(meta.mbr, meta.mbr2);
}

action copy_mbr_mbr2() {
    modify_field(meta.mbr2, meta.mbr);
}

action acc_load() {
    modify_field(as.acc, meta.mbr);
}

action acc2_load() {
    modify_field(as.acc2, meta.mbr);
}

action mark_processed_packet() {
    modify_field(as.flag_redirect, 1);
}

action unmark_processed_packet() {
    modify_field(as.flag_redirect, 0);
}

action enable_execution() {
    bit_and(meta.disabled, meta.disabled, 126);
}

action return_to_sender() {
    swap(ipv4.srcAddr, ipv4.dstAddr);
    swap(ethernet.srcAddr, ethernet.dstAddr);
    add_to_field(udp.len, 6);
    modify_field(as.flag_rts, 1);
    modify_field(meta.rts, 1);
}

action memfault() {
    modify_field(as.flag_mfault, 1);
    return_to_sender();
}

action hash5tuple() {
    modify_field_with_hash_based_offset(meta.mar, 0, l4_5tuple_hash, 16);
}

action hash_id() {
    modify_field_with_hash_based_offset(meta.mar, 0, id_list_hash, 65536);
}

action set_port(mirror_id) {
    modify_field(meta.rtsid, mirror_id);
    modify_field(as.flag_rts, 1);
}

action get_random_port() {
    modify_field(meta.mbr, 0, 3);
}

action goto_aux() {
    modify_field(as.flag_aux, 1);
}

action min_mbr_mbr2() {
    min(meta.mbr, meta.mbr, meta.mbr2);
}