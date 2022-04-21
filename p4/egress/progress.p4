action step_1() {
    modify_field(ap[0].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[0]);
}

table proceed_1 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_1;
    }
}

action step_2() {
    modify_field(ap[1].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[1]);
}

table proceed_2 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_2;
    }
}

action step_3() {
    modify_field(ap[2].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[2]);
}

table proceed_3 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_3;
    }
}

action step_4() {
    modify_field(ap[3].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[3]);
}

table proceed_4 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_4;
    }
}

action step_5() {
    modify_field(ap[4].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[4]);
}

table proceed_5 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_5;
    }
}

action step_6() {
    modify_field(ap[5].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[5]);
}

table proceed_6 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_6;
    }
}

action step_7() {
    modify_field(ap[0].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[0]);
}

table proceed_7 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_7;
    }
}

action step_8() {
    modify_field(ap[1].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[1]);
}

table proceed_8 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_8;
    }
}

action step_9() {
    modify_field(ap[2].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[2]);
}

table proceed_9 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_9;
    }
}

action step_10() {
    modify_field(ap[3].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[3]);
}

table proceed_10 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_10;
    }
}

action step_11() {
    modify_field(ap[4].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[4]);
}

table proceed_11 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_11;
    }
}

action step_12() {
    modify_field(ap[5].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[5]);
}

table proceed_12 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_12;
    }
}

action step_13() {
    modify_field(ap[6].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[6]);
}

table proceed_13 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_13;
    }
}

action step_14() {
    modify_field(ap[7].flags, 1);
    //add_to_field(meta.burnt_ipv4, 4);
    //add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[7]);
}

table proceed_14 {
    reads {
        meta.complete       : exact;
        //meta.loop           : exact;
    }
    actions {
        step_14;
    }
}