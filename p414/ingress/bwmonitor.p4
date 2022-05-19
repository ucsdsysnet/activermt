counter active_traffic {
    type            : packets_and_bytes;
    instance_count  : 256;
}

action count_active_traffic() {
    count(active_traffic, as.fid);
}

table active_traffic_counter {
    actions {
        count_active_traffic;
    }
    default_action : count_active_traffic;
}

counter generic_traffic {
    type            : packets_and_bytes;
    instance_count  : 1;
}

action count_generic_traffic() {
    count(generic_traffic, 0);
}

table generic_traffic_monitor {
    actions {
        count_generic_traffic;
    }
    default_action : count_generic_traffic;
}

counter ig_traffic {
    type            : packets_and_bytes;
    instance_count  : 1;
}

action count_traffic_ig() {
    count(ig_traffic, 0);
}

table ig_traffic_counter {
    actions {
        count_traffic_ig;
    }
    default_action : count_traffic_ig;
}