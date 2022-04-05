action step_#() {
    modify_field(ap[?].flags, 1);
    add_to_field(meta.burnt_ipv4, 4);
    add_to_field(meta.burnt_udp, 4);
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