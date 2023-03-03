struct metadata_t {
    // <metadata>
    bit<32>  ifid;  // Logical Interface ID
    bit<16>  brid;  // Bridging Domain ID
    bit<16>  vrf;   // VRF ID
    bit<1>   l3;    // Set if routed
    // </metadata>
}