action setegr(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
    modify_field(as.flag_aux, 0);
}

action setrts(mirror_id) {
    modify_field(meta.rtsid, mirror_id);
}

table forward {
    reads {
        as.flag_aux         : exact;
        as.flag_ack         : exact;
        as.flag_redirect    : exact;
        ipv4.dstAddr        : lpm;
    }
    actions {
        setegr;
    }
}

table backward {
    reads {
        ipv4.srcAddr    : exact;
    }
    actions {
        setrts;
    }
}

action passthru() {
    bypass_egress();
}

table check_completion {
    reads {
        as.flag_done : exact;
    }
    actions {
        passthru;
    }
}