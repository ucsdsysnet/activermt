action step_#() {
    modify_field(ap[?].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
    //remove_header(ap[?]);
}

table proceed_# {
    reads {
        meta.complete       : exact;
        meta.loop           : exact;
    }
    actions {
        step_#;
    }
}