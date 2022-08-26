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

enum bit<2> active_malloc_t {
    REQ = 1,
    GET = 2
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
    bit<16>     flags;
    /*bit<4>      data_offset;
    bit<3>      res;
    bit<3>      ecn;
    bit<6>      ctrl;*/
    bit<16>     window;
    bit<16>     checksum;
    bit<16>     urgent_ptr;
}

/*header tcp_option_h {
    varbit<320> data;
}*/

header active_initial_h {
    bit<32>         ACTIVEP4;
    bit<1>          opt_arg;
    bit<1>          opt_data;
    bit<1>          rst_seq;
    bit<1>          flag_rts;
    bit<1>          flag_marked;
    bit<1>          flag_aux;
    bit<1>          flag_ack;
    bit<1>          flag_done;
    bit<1>          flag_mfault;
    bit<1>          flag_exceeded;
    active_malloc_t flag_reqalloc;
    bit<1>          flag_allocated;
    bit<1>          flag_pending;
    bit<2>          _padding;
    bit<16>         fid;
    bit<16>         seq;
}

header active_data_h {
    bit<32>     data_0;
    bit<32>     data_1;
    bit<32>     data_2;
    bit<32>     data_3;
}

header active_instruction_h {
    bit<6>      flags;
    bit<1>      tr_nz;
    bit<1>      goto;
    bit<8>      opcode;
}

/*header active_bulk_data_h {
    bit<32>     data_0;
    bit<32>     data_1;
    bit<32>     data_2;
    bit<32>     data_3;
    bit<32>     data_4;
    bit<32>     data_5;
    bit<32>     data_6;
    bit<32>     data_7;
    bit<32>     data_8;
    bit<32>     data_9;
    bit<32>     data_10;
    bit<32>     data_11;
    bit<32>     data_12;
    bit<32>     data_13;
    bit<32>     data_14;
    bit<32>     data_15;
    bit<32>     data_16;
    bit<32>     data_17;
    bit<32>     data_18;
    bit<32>     data_19;
}*/

header active_malloc_req_h {
    bit<8>      constr_lb_0;
    bit<8>      constr_ub_0;
    bit<8>      constr_ms_0;
    bit<8>      constr_lb_1;
    bit<8>      constr_ub_1;
    bit<8>      constr_ms_1;
    bit<8>      constr_lb_2;
    bit<8>      constr_ub_2;
    bit<8>      constr_ms_2;
    bit<8>      constr_lb_3;
    bit<8>      constr_ub_3;
    bit<8>      constr_ms_3;
    bit<8>      constr_lb_4;
    bit<8>      constr_ub_4;
    bit<8>      constr_ms_4;
    bit<8>      constr_lb_5;
    bit<8>      constr_ub_5;
    bit<8>      constr_ms_5;
    bit<8>      constr_lb_6;
    bit<8>      constr_ub_6;
    bit<8>      constr_ms_6;
    bit<8>      constr_lb_7;
    bit<8>      constr_ub_7;
    bit<8>      constr_ms_7;
}

header active_malloc_h {
    bit<16>     start;
    bit<16>     end;
}

@flexible
header bridged_metadata_h {
    bit<1>      duplicate;
    bit<1>      complete;
    bit<1>      rts;
    bit<1>      disabled; 
    bit<16>     randnum;
    bit<16>     tcp_length;
    bit<32>     hash_data_0;
    bit<32>     hash_data_1;
    bit<32>     hash_data_2;
    bit<32>     hash_data_3;
    bit<32>     hash_data_4;
    bit<32>     mar;
    bit<32>     mbr;
    bit<32>     mbr2;
    bit<32>     inc;
    bit<32>     ig_timestamp;
    bit<32>     eg_timestamp;
    bit<32>     qdelay;
    bit<32>     ig_pktcount;
    bit<32>     eg_pktcount;
    bit<10>     mirror_sessid;
    bit<1>      mirror_en;
    bit<7>      mirror_iter;
    bit<2>      _padding;
    bit<1>      carry;
    bit<8>      fid;
}

header resubmit_header_t {
    bit<32>     buf;
    bit<32>     addr;
}

header eg_port_mirror_h {
    pkt_type_t  pkt_type;
}

@flexible
struct ig_metadata_t {
    resubmit_header_t   resubmit_data;
    bit<8>      port_change;
    bit<8>      set_clr_seq;
    bit<8>      prev_exec;
    bit<16>     instr_count;
    bit<16>     seq_offset;
    bit<16>     seq_addr;
    bit<16>     vport;
    bit<16>     chksum_tcp;
    bit<16>     phash;
    bit<32>     idx;
}

struct eg_metadata_t {
    bit<10>     mirror_sessid;
    bit<9>      egress_port;
    bit<1>      port_change;
}

struct ingress_headers_t {
    bridged_metadata_h                          meta;
    ethernet_h                                  ethernet;
    active_initial_h                            ih;
    active_data_h                               data;
    active_malloc_req_h                         malloc;
    active_malloc_h[NUM_STAGES]                 alloc;
    //active_bulk_data_h                          bulk_data;
    active_instruction_h[MAX_INSTRUCTIONS]      instr;
    ipv4_h                                      ipv4;
    udp_h                                       udp;
    tcp_h                                       tcp;
    //tcp_option_h                                tcpopts;
}

struct egress_headers_t {
    bridged_metadata_h                          meta;
    ethernet_h                                  ethernet;
    active_initial_h                            ih;
    active_malloc_h[NUM_STAGES]                 alloc;
    active_data_h                               data;
    //active_bulk_data_h                          bulk_data;
    active_instruction_h[MAX_INSTRUCTIONS]      instr;
}

/*struct memory_object_t {
    bit<16> key;
    bit<16> value;
}*/

struct malloc_digest_t {
    bit<16>     fid;
    bit<8>      constr_lb_0;
    bit<8>      constr_ub_0;
    bit<8>      constr_ms_0;
    bit<8>      constr_lb_1;
    bit<8>      constr_ub_1;
    bit<8>      constr_ms_1;
    bit<8>      constr_lb_2;
    bit<8>      constr_ub_2;
    bit<8>      constr_ms_2;
    bit<8>      constr_lb_3;
    bit<8>      constr_ub_3;
    bit<8>      constr_ms_3;
    bit<8>      constr_lb_4;
    bit<8>      constr_ub_4;
    bit<8>      constr_ms_4;
    bit<8>      constr_lb_5;
    bit<8>      constr_ub_5;
    bit<8>      constr_ms_5;
    bit<8>      constr_lb_6;
    bit<8>      constr_ub_6;
    bit<8>      constr_ms_6;
    bit<8>      constr_lb_7;
    bit<8>      constr_ub_7;
    bit<8>      constr_ms_7;      
} 