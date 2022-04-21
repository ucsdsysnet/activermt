parser start {
    extract(ethernet);
    return select(ethernet.etherType) {
        0x0800 : parse_ipv4;
        default: ingress;
    }
}

parser parse_ipv4 {
    extract(ipv4);
    return select(ipv4.protocol) {
        0x11    : parse_udp;
        0x6     : parse_tcp;
        default : ingress;
    }
}

parser parse_udp {
    extract(udp);
    return select(udp.dstPort) {
        9876    : parse_active_state;
        9877    : parse_pktgen_ts;
        default : ingress;
    }
}

parser parse_tcp {
    extract(tcp);
    return parse_tcp_options;
}

parser parse_tcp_options {
    return select(tcp.dataOffset) {
        5       : parse_tcp_option_0b;
        6       : parse_tcp_option_4b;
        7       : parse_tcp_option_8b;
        8       : parse_tcp_option_12b;
        9       : parse_tcp_option_16b;
        10       : parse_tcp_option_20b;
        11       : parse_tcp_option_24b;
        12       : parse_tcp_option_28b;
        13       : parse_tcp_option_32b;
        14       : parse_tcp_option_36b;
        15      : parse_tcp_option_40b;
        default : ingress;
    }
}

parser parse_tcp_option_0b {
    return select(ipv4.totalLen) {
        40      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_4b {
    extract(tcpo_4b);
    return select(ipv4.totalLen) {
        44      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_8b {
    extract(tcpo_8b);
    return select(ipv4.totalLen) {
        48      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_12b {
    extract(tcpo_12b);
    return select(ipv4.totalLen) {
        52      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_16b {
    extract(tcpo_16b);
    return select(ipv4.totalLen) {
        56      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_20b {
    extract(tcpo_20b);
    return select(ipv4.totalLen) {
        60      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_24b {
    extract(tcpo_24b);
    return select(ipv4.totalLen) {
        64      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_28b {
    extract(tcpo_28b);
    return select(ipv4.totalLen) {
        68      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_32b {
    extract(tcpo_32b);
    return select(ipv4.totalLen) {
        72      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_36b {
    extract(tcpo_36b);
    return select(ipv4.totalLen) {
        76      : ingress;
        default : parse_active_state;
    }
}

parser parse_tcp_option_40b {
    extract(tcpo_40b);
    return select(ipv4.totalLen) {
        80      : ingress;
        default : parse_active_state;
    }
}

parser parse_pktgen_ts {
    extract(ts);
    return parse_active_state;
}

parser parse_active_state {
    extract(as);
    return select(as.ACTIVEP4) {
        0x12345678  : check_for_completion;
        default     : ingress;
    }
}

parser check_for_completion {
    return select(as.flag_done) {
        0x01    : ingress;
        //default : init_program;
        default : parse_active_program;
    }
}

/*parser init_program {
    return select(as.flag_aux) {
        0x01        : skip_block;
        default     : continue_parsing;
    }
}

@pragma force_shift ingress 128
@pragma force_shift egress 128
parser skip_block {
    return attempt_resume;
}

parser attempt_resume {
    return select(current(0, 4)) {
        0x03    : continue_parsing;
        default : skip_block;
    }
}

parser continue_parsing {
    return select(current(0, 4)) {
        0x01    : skip_instruction;
        default : parse_active_program;
    }
}

@pragma force_shift ingress 32
@pragma force_shift egress 32
parser skip_instruction {
    return continue_parsing;
}*/

parser parse_active_program {
    extract(ap[next]);
    return select(latest.opcode) {
        0x01    : mark_eof;
        default : parse_active_program;
    }
}

parser mark_eof {
    set_metadata(meta.eof, 1);
    return ingress;
}