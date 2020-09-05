action step_#() {
    modify_field(ap[?].flags, 1);
    add_to_field(meta.burnt_ipv4, 6);
    add_to_field(meta.burnt_udp, 6);
}

table proceed_# {
    reads {
        meta.loop           : exact;
    }
    actions {
        step_#;
    }
}