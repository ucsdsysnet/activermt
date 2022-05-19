header_type ethernet_t {
    fields {
        dstAddr   : 48;
        srcAddr   : 48;
        etherType : 16;
    }
}

header_type ipv4_t {
    fields {
        version        : 4;
        ihl            : 4;
        diffserv       : 8;
        totalLen       : 16;
        identification : 16;
        flags          : 3;
        fragOffset     : 13;
        ttl            : 8;
        protocol       : 8;
        hdrChecksum    : 16;
        srcAddr        : 32;
        dstAddr        : 32;
    }
}

header_type udp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        len     : 16;
        cksum   : 16;
    }
}

header_type tcp_t {
    fields {
        srcPort     : 16;
        dstPort     : 16;
        seqNo       : 32;
        ackNo       : 32;
        dataOffset  : 4;
        res         : 3;
        ecn         : 3;
        ctrl        : 6;
        window      : 16;
        checksum    : 16;
        urgentPtr   : 16;
    }
}

header_type tcp_option_4B_t {
    fields {
        option      : 32;
    }
}

header_type tcp_option_8B_t {
    fields {
        option      : 64;
    }
}

header_type tcp_option_12B_t {
    fields {
        option      : 96;
    }
}

header_type tcp_option_16B_t {
    fields {
        option      : 128;
    }
}

header_type tcp_option_20B_t {
    fields {
        option      : 160;
    }
}

header_type tcp_option_24B_t {
    fields {
        option      : 192;
    }
}

header_type tcp_option_28B_t {
    fields {
        option      : 224;
    }
}

header_type tcp_option_32B_t {
    fields {
        option      : 256;
    }
}

header_type tcp_option_36B_t {
    fields {
        option      : 288;
    }
}

header_type tcp_option_40B_t {
    fields {
        option      : 320;
    }
}

header_type pktgen_ts_t {
    fields {
        padding         : 48;
        timestamp       : 64;
        magic           : 16;
    }
}

header_type active_state_t {
    fields {
        ACTIVEP4        : 32;
        flag_redirect   : 1;
        flag_igclone    : 1;
        flag_bypasseg   : 1;
        flag_rts        : 1;
        flag_marked     : 1;
        flag_aux        : 1;
        flag_ack        : 1;
        flag_done       : 1;
        flag_mfault     : 1;
        flag_exceeded   : 1;
        flag_reqalloc   : 1;
        flag_allocated  : 1;
        flag_precache   : 1;
        flag_usecache   : 1;
        padding         : 2;
        fid             : 16;
        seq             : 32;
        acc             : 16;
        acc2            : 16;
        id              : 16;
        freq            : 16;
    }
}

header_type active_program_t {
    fields {
        flags   : 4;
        goto    : 4;
        opcode  : 8;
        arg     : 16;
    }
}

header_type metadata_t {
    fields {
        loop        : 1;
        duplicate   : 1;
        complete    : 1;
        skipped     : 1;
        rts         : 1;
        eof         : 1;
        chain       : 1;
        alloc_init  : 1;
        disabled    : 2;
        color       : 3;
        quota_start : 4;
        quota_end   : 4; 
        pc          : 4;
        cycles      : 8;
        rtsid       : 16;
        fwdid       : 16;
        mar         : 16;
        mbr         : 16;
        mbr2        : 16;
        burnt_ipv4  : 16;
        burnt_udp   : 16;
        hashblock_1 : 16;
        hashblock_2 : 16;
        hashblock_3 : 16;
        hashblock_4 : 16;
        hashblock_5 : 16;
        hashblock_6 : 16;
        hashblock_7 : 16;
        mirror_type : 1;
        mirror_id   : 10;
        mirror_sess : 10;
    }
}