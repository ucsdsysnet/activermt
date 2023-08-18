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
    <third-party-metadata>
}

@flexible
struct eg_metadata_t {
    bit<10>     mirror_sessid;
    bit<9>      egress_port;
    bit<1>      port_change;
}