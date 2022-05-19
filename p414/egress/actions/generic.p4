action skip() {}

action clean_ih() {
    remove_header(as);
}

action drop_ig() {
    drop();
}

action drop_eg() {
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
} 

action cancel_drop_eg() {
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

action cancel_complete() {
    modify_field(meta.complete, 0);
    modify_field(as.flag_done, 0);
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

action acc_to_mbr() {
    modify_field(meta.mbr, as.acc);
}

action mark_packet() {
    modify_field(as.flag_marked, 1);
}

action enable_execution() {
    bit_and(meta.disabled, meta.disabled, 2);
}

/*action swap_addr() {
    swap(ipv4.srcAddr, ipv4.dstAddr);
    swap(ethernet.srcAddr, ethernet.dstAddr);
}*/

action rts_addr() {
    modify_field(ipv4.dstAddr, ipv4.srcAddr);
    modify_field(ethernet.dstAddr, ethernet.srcAddr);
}

action return_to_sender() {
    //swap(ipv4.srcAddr, ipv4.dstAddr);
    //swap(ethernet.srcAddr, ethernet.dstAddr);
    modify_field(ipv4.dstAddr, ipv4.srcAddr);
    modify_field(ethernet.dstAddr, ethernet.srcAddr);
    add_to_field(udp.len, 4);
    modify_field(as.flag_rts, 1);
    modify_field(meta.rts, 1);
    modify_field(meta.fwdid, meta.rtsid);
}

action memfault() {
    modify_field(as.flag_mfault, 1);
    modify_field(as.acc, meta.mar);
    complete();
    return_to_sender();
}

action set_port(mirror_id) {
    modify_field(meta.rtsid, mirror_id);
    modify_field(as.flag_rts, 1);
}

action goto_aux() {
    modify_field(as.flag_aux, 1);
}

action min_mbr_mbr2() {
    min(meta.mbr, meta.mbr, meta.mbr2);
}

action min_mbr2_mbr() {
    min(meta.mbr2, meta.mbr, meta.mbr2);
}

action mbr_equals_mbr2() {
    bit_xor(meta.mbr, meta.mbr, meta.mbr2);
}

action hash_generic() {
    modify_field_with_hash_based_offset(meta.mar, 0, generic_hash, 65536);
}

action hash_acc2() {
    modify_field_with_hash_based_offset(meta.mar, 0, acc2_list_hash, 65536);
}

/*action hash_5tuple() {
    modify_field_with_hash_based_offset(meta.mar, 0, l4_5tuple_hash, 65536);
}*/

action load_hashlist_ipv4src() {
    modify_field(meta.hashblock_1, ipv4.srcAddr, 0xFFFF);
    modify_field_with_shift(meta.hashblock_2, ipv4.srcAddr, 16, 0xFFFF);
}

action load_hashlist_ipv4dst() {
    modify_field(meta.hashblock_3, ipv4.dstAddr, 0xFFFF);
    modify_field_with_shift(meta.hashblock_4, ipv4.dstAddr, 16, 0xFFFF);
}

action load_hashlist_ipv4proto() {
    modify_field(meta.hashblock_5, ipv4.protocol);
}

action load_hashlist_udpsrcport() {
    modify_field(meta.hashblock_6, udp.srcPort);
}

action load_hashlist_udpdstport() {
    modify_field(meta.hashblock_7, udp.dstPort);
}

action load_hashlist_5tuple() {
    modify_field(meta.hashblock_1, ipv4.srcAddr, 0xFFFF);
    modify_field_with_shift(meta.hashblock_2, ipv4.srcAddr, 16, 0xFFFF);
    modify_field(meta.hashblock_3, ipv4.dstAddr, 0xFFFF);
    modify_field_with_shift(meta.hashblock_4, ipv4.dstAddr, 16, 0xFFFF);
    modify_field(meta.hashblock_5, ipv4.protocol);
    modify_field(meta.hashblock_6, udp.srcPort);
    modify_field(meta.hashblock_7, udp.dstPort);
}

action copy_mar_mbr() {
    modify_field(meta.mar, meta.mbr);
}

action copy_mbr_mar() {
    modify_field(meta.mbr, meta.mar);
}

action bit_and_mar_mbr() {
    bit_and(meta.mar, meta.mar, meta.mbr);
}

action mar_add_mbr() {
    add_to_field(meta.mar, meta.mbr);
}

action set_port_ig() {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, meta.mbr);
}