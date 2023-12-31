//    Copyright 2023 Rajdeep Das, University of California San Diego.

//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at

//        http://www.apache.org/licenses/LICENSE-2.0

//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

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
    bit<1>          flag_initiated;
    bit<1>          flag_ack;
    bit<1>          flag_done;
    bit<1>          flag_mfault;
    bit<1>          flag_remapped;
    active_malloc_t flag_reqalloc;
    bit<1>          flag_allocated;
    bit<1>          flag_pending;
    bit<1>          flag_leader;
    bit<1>          flag_preload;
    bit<16>         fid;
    bit<16>         seq;
}

header active_data_h {
    bit<32>     data_0;
    bit<32>     data_1;
    bit<32>     data_2;
    bit<32>     data_3;
}

header active_data_extended_h {
    bit<32>     data;
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
    bit<16>     proglen;
    bit<8>      iglim;
    bit<8>      mem_0;
    bit<8>      mem_1;
    bit<8>      mem_2;
    bit<8>      mem_3;
    bit<8>      mem_4;
    bit<8>      mem_5;
    bit<8>      mem_6;
    bit<8>      mem_7;
    bit<8>      dem_0;
    bit<8>      dem_1;
    bit<8>      dem_2;
    bit<8>      dem_3;
    bit<8>      dem_4;
    bit<8>      dem_5;
    bit<8>      dem_6;
    bit<8>      dem_7;
}

header active_malloc_h {
    bit<32>     offset;
    bit<32>     size;
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
    bit<10>      _padding;
    bit<9>      ingress_port;
    bit<1>      carry;
    bit<1>      remap;
    bit<16>     fid;
    // bit<32>     paddr_mask;
    // bit<32>     paddr_offset;
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
    bit<8>      app_fid;
    bit<8>      app_instance_id;
    bit<8>      leader_id;
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
    active_data_extended_h[MAX_EXTENDED_DATA]   extended_data;
    active_malloc_req_h                         malloc;
    active_malloc_h[NUM_STAGES]                 alloc;
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
    active_data_extended_h[MAX_EXTENDED_DATA]   extended_data;
    active_instruction_h[MAX_INSTRUCTIONS]      instr;
}

/*struct memory_object_t {
    bit<16> key;
    bit<16> value;
}*/

struct malloc_digest_t {
    bit<16>     fid;
    bit<16>     proglen;
    bit<8>      iglim;
    bit<8>      mem_0;
    bit<8>      mem_1;
    bit<8>      mem_2;
    bit<8>      mem_3;
    bit<8>      mem_4;
    bit<8>      mem_5;
    bit<8>      mem_6;
    bit<8>      mem_7;
    bit<8>      dem_0;
    bit<8>      dem_1;
    bit<8>      dem_2;
    bit<8>      dem_3;
    bit<8>      dem_4;
    bit<8>      dem_5;
    bit<8>      dem_6;
    bit<8>      dem_7;      
}

struct remap_digest_t {
    bit<16>     fid;
    bit<1>      flag_remapped;
    bit<1>      flag_ack;
    bit<1>      flag_initiated;
}