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
    
    bit<32>  ifid;  // Logical Interface ID
    bit<16>  brid;  // Bridging Domain ID
    bit<16>  vrf;   // VRF ID
    bit<1>   l3;    // Set if routed
    // 
}

@flexible
struct eg_metadata_t {
    bit<10>     mirror_sessid;
    bit<9>      egress_port;
    bit<1>      port_change;
}