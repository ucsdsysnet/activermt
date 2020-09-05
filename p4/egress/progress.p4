action step_1() {
    modify_field(ap[0].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_1 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_1;
    }
}

action step_2() {
    modify_field(ap[1].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_2 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_2;
    }
}

action step_3() {
    modify_field(ap[2].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_3 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_3;
    }
}

action step_4() {
    modify_field(ap[3].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_4 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_4;
    }
}

action step_5() {
    modify_field(ap[4].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_5 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_5;
    }
}

action step_6() {
    modify_field(ap[5].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_6 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_6;
    }
}

action step_7() {
    modify_field(ap[6].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_7 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_7;
    }
}

action step_8() {
    modify_field(ap[7].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_8 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_8;
    }
}

action step_9() {
    modify_field(ap[8].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_9 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_9;
    }
}

action step_10() {
    modify_field(ap[9].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_10 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_10;
    }
}

action step_11() {
    modify_field(ap[10].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_11 {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_11;
    }
}