action reset_aux() {
    modify_field(as.flag_aux, 0);
    modify_field(meta.skipped, 0);
}

action set_mirror(dst) {
    modify_field(meta.mirror_type, 1);
    modify_field(meta.mirror_sess, dst);
    clone_egress_pkt_to_egress(dst, cycle_metadata);
    add_to_field(ipv4.identification, 1000);
    count(recirc, 0);
}

action cycle_aux() {
    set_mirror(meta.fwdid);
    reset_aux();
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
    subtract_from_field(ipv4.ttl, 1);
}

action cycle_clone_aux() {
    set_mirror(meta.fwdid);
    reset_aux();
    subtract_from_field(ipv4.ttl, 1);
}

action cycle() {
    set_mirror(meta.fwdid);
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
    subtract_from_field(ipv4.ttl, 1);
}

action cycle_clone() {
    set_mirror(meta.fwdid);
    subtract_from_field(ipv4.ttl, 1);
}

action cycle_redirect() {
    set_mirror(meta.rtsid);
    modify_field(as.flag_rts, 0);
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
}

table progress {
    reads {
        as.flag_rts     : exact;
        as.flag_aux     : exact;
        meta.skipped    : exact;
        meta.complete   : exact;
        meta.duplicate  : exact;
        meta.cycles     : range;
    }
    actions {
        cycle;
        cycle_clone;
        cycle_redirect;
        cycle_aux;
        cycle_clone_aux;
    }
}

action update_lengths() {
    subtract_from_field(ipv4.totalLen, meta.burnt_ipv4);
    subtract_from_field(udp.len, meta.burnt_udp);
}

action update_burnt() {
    subtract_from_field(meta.burnt_ipv4, 4);
    modify_field(meta.rts, 0);
}

table lenupdate {
    reads {
        meta.rts        : exact;
        meta.complete   : exact;
    }
    actions {
        update_lengths;
        update_burnt;
    }
}

action update_cycles() {
    subtract_from_field(meta.cycles, 1);
}

table cycleupdate {
    actions {
        update_cycles;
    }
}