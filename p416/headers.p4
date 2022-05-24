typedef bit<48> mac_addr_t;
typedef bit<32> ipv4_addr_t;

enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    ARP  = 0x0806,
    AP4  = 0x83B2
}

enum bit<8> ipv4_protocol_t {
    UDP = 0x11,
    TCP = 0x06
}

enum bit<16> active_port_t {
    UDP = 9876,
    TCP = 6378
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header ipv4_h {
    bit<4>          version;
    bit<4>          ihl;
    bit<8>          diffserv;
    bit<16>         total_len;
    bit<16>         identification;
    bit<3>          flags;
    bit<13>         frag_offset;
    bit<8>          ttl;
    ipv4_protocol_t protocol;
    bit<16>         hdr_checksum;
    ipv4_addr_t     src_addr;
    ipv4_addr_t     dst_addr;
}

header udp_h {
    bit<16>     src_port;
    bit<16>     dst_port;
    bit<16>     len;
    bit<16>     cksum;    
}

header tcp_h {
    bit<16>     src_port;
    bit<16>     dst_port;
    bit<32>     seq_no;
    bit<32>     ack_no;
    bit<4>      data_offset;
    bit<3>      res;
    bit<3>      ecn;
    bit<6>      ctrl;
    bit<16>     window;
    bit<16>     checksum;
    bit<16>     urgent_ptr;
}

header tcp_option_h {
    varbit<320> data;
}

header active_initial_h {
    bit<32>     ACTIVEP4;
    bit<1>      flag_redirect;
    bit<1>      flag_igclone;
    bit<1>      flag_bypasseg;
    bit<1>      flag_rts;
    bit<1>      flag_marked;
    bit<1>      flag_aux;
    bit<1>      flag_ack;
    bit<1>      flag_done;
    bit<1>      flag_mfault;
    bit<1>      flag_exceeded;
    bit<1>      flag_reqalloc;
    bit<1>      flag_allocated;
    bit<1>      flag_precache;
    bit<1>      flag_usecache;
    bit<2>      padding;
    bit<16>     fid;
    bit<16>     seq;
    bit<16>     acc;
    bit<16>     acc2;
    bit<16>     data;
    bit<16>     data2;
    bit<16>     res;
}

header active_instruction_h {
    bit<7>      flags;
    bit<1>      goto;
    bit<8>      opcode;
    bit<16>     arg;
}

@flexible
header bridged_metadata_h {
    bit<1>      duplicate;
    bit<1>      complete;
    bit<1>      rts;
    bit<1>      disabled; 
    bit<8>      cycles;
    bit<16>     rtsid;
    bit<16>     fwdid;
    bit<16>     mar;
    bit<16>     mbr;
    bit<16>     mbr2;
    MirrorId_t  egr_mir_ses;
    pkt_type_t  pkt_type;
    bit<2>      padding;
    bit<16>     randnum;
    bit<16>     tcp_length;
    bit<32>     ipv4_src;
    bit<32>     ipv4_dst;
    bit<8>      ipv4_protocol;
    bit<16>     l4_src;
    bit<16>     l4_dst;
}

header eg_port_mirror_h {
    pkt_type_t  pkt_type;
}

struct ig_metadata_t {
    bit<8>      port_change;
    bit<8>      set_clr_seq;
    bit<8>      prev_exec;
    bit<16>     instr_count;
    bit<16>     seq_offset;
    bit<16>     seq_addr;
    bit<16>     vport;
}

struct eg_metadata_t {
    bit<16>     instr_count;
}

struct ingress_headers_t {
    bridged_metadata_h                          meta;
    ethernet_h                                  ethernet;
    active_initial_h                            ih;
    active_instruction_h[MAX_INSTRUCTIONS]      instr;
    ipv4_h                                      ipv4;
    udp_h                                       udp;
    tcp_h                                       tcp;
    tcp_option_h                                tcpopts;
}

struct egress_headers_t {
    bridged_metadata_h                          meta;
    ethernet_h                                  ethernet;
    active_initial_h                            ih;
    active_instruction_h[MAX_INSTRUCTIONS]      instr;
}