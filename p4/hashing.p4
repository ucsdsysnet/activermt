field_list ipv4_checksum_list {
    ipv4.version;
    ipv4.ihl;
    ipv4.diffserv;
    ipv4.totalLen;
    ipv4.identification;
    ipv4.flags;
    ipv4.fragOffset;
    ipv4.ttl;
    ipv4.protocol;
    ipv4.srcAddr;
    ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input        { ipv4_checksum_list; }
    algorithm    : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum;
    update ipv4_checksum;
}

field_list mar_list {
    meta.mbr;
}

field_list id_list {
    as.id;
}

field_list_calculation id_list_hash {
    input           { id_list; }
    algorithm       : identity;
    output_width    : 16;
}

field_list l4_5tuple_list {
    ipv4.protocol;
    ipv4.srcAddr;
    ipv4.dstAddr;
    udp.dstPort;
    udp.srcPort;
}

field_list_calculation l4_5tuple_hash {
    input           { l4_5tuple_list; }
    algorithm       : identity;
    output_width    : 16;
}

field_list cycle_metadata {
    meta.lru_target;
    meta.rtsid;
    meta.pc;
    meta.loop;
    meta.disabled;
    meta.complete;
    meta.quota_start;
    meta.quota_end;
    meta.mar;
    meta.mbr;
    meta.mbr2;
    meta.mirror_sess;
    meta.mirror_type;
    meta.skipped;
    meta.burnt_ipv4;
    meta.burnt_udp;
    meta.rts;
    meta.cycles;
}