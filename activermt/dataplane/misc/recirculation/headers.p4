typedef bit<48> mac_addr_t;

enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    ARP  = 0x0806
}

header ethernet_h {
    mac_addr_t   dst_addr;
    mac_addr_t   src_addr;
    ether_type_t ether_type;
}

header resubmit_h {
    bit<32>     buf;
    bit<32>     addr;
}

@flexible
header bridged_metadata_h {
    bit<32>     mar;
    bit<32>     mbr;
    bit<32>     mbr2;
    bit<1>      mirror_en;
    bit<10>     mirror_sessid;
    bit<7>      iter;
    bit<6>      _padding;
}

struct ig_metadata_t {
    resubmit_h  resubmit_data;
}

struct eg_metadata_t {
    bit<10>     mirror_sessid;
}

struct ingress_headers_t {
    bridged_metadata_h  meta;                  
    ethernet_h          ethernet;
}

struct egress_headers_t {
    bridged_metadata_h  meta;
    ethernet_h          ethernet;
}