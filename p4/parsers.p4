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

parser parse_pktgen_ts {
    extract(ts);
    return parse_active_state;
}

parser parse_active_state {
    extract(as);
    return select(as.flag_done) {
        0x01    : ingress;
        default : init_program;
    }
}

parser init_program {
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
}

parser parse_active_program {
    extract(ap[next]);
    return select(latest.opcode) {
        0x01    : ingress;
        default : parse_active_program;
    }
}