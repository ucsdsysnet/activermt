counter numpkt {
    type            : packets;
    instance_count  : 128;
}

action setcycleparams(port, fwdid) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
    modify_field(as.flag_aux, 0);
    modify_field(meta.fwdid, fwdid);
    count(numpkt, as.fid);
}

action setegr(port, fwdid) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
    modify_field(meta.fwdid, fwdid);
    count(numpkt, 0);
}

action setrts(mirror_id) {
    modify_field(meta.rtsid, mirror_id);
}

table forward {
    reads {
        ipv4.dstAddr    : lpm;
    }
    actions {
        setegr;
    }
}

table fwdparams {
    reads {
        as.flag_aux         : exact;
        as.flag_ack         : exact;
        as.flag_redirect    : exact;
        ipv4.dstAddr        : lpm;
    }
    actions {
        setcycleparams;
    }
}

table backward {
    reads {
        ipv4.srcAddr    : lpm;
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