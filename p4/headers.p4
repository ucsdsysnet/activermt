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

header_type pktgen_ts_t {
    fields {
        padding         : 48;
        timestamp       : 64;
        magic           : 16;
    }
}

header_type active_state_t {
    fields {
        flag_redirect   : 1;
        flag_igclone    : 1;
        flag_bypasseg   : 1;
        flag_rts        : 1;
        flag_gc         : 1;
        flag_aux        : 1;
        flag_ack        : 1;
        flag_done       : 1;
        flag_mfault     : 1;
        flag_resetfreq  : 1;
        flag_reqalloc   : 1;
        flag_allocated  : 1;
        padding         : 4;
        fid             : 16;
        acc             : 16;
        acc2            : 16;
        id              : 16;
        freq            : 16;
    }
}

header_type active_program_t {
    fields {
        flags   : 8;
        opcode  : 8;
        arg     : 16;
        goto    : 8;
    }
}

header_type metadata_t {
    fields {
        pc          : 8;
        quota_start : 8;
        quota_end   : 8; 
        loop        : 8;
        duplicate   : 1;
        mar         : 16;
        base        : 16;
        mbr         : 16;
        mbr2        : 16;
        mar_base    : 16;
        disabled    : 8;
        mirror_type : 1;
        mirror_sess : 10;
        complete    : 1;
        rtsid       : 16;
        lru_target  : 4;
        skipped     : 1;
        burnt_ipv4  : 16;
        burnt_udp   : 16;
        rts         : 1;
        color       : 4;
        digest      : 1;
        reset       : 1;
        alloc_init  : 1;
        cycles      : 8;
    }
}