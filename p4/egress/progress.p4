action step_1() {
    modify_field(ap[0].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_1 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_1;
    }
}

action step_2() {
    modify_field(ap[1].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_2 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_2;
    }
}

action step_3() {
    modify_field(ap[2].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_3 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_3;
    }
}

action step_4() {
    modify_field(ap[3].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_4 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_4;
    }
}

action step_5() {
    modify_field(ap[0].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_5 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_5;
    }
}

action step_6() {
    modify_field(ap[1].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_6 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_6;
    }
}

action step_7() {
    modify_field(ap[2].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_7 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_7;
    }
}

action step_8() {
    modify_field(ap[3].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
}

table proceed_8 {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_8;
    }
}