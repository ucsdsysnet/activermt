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

parser EgressParser(
    packet_in                       pkt,
    out egress_headers_t            hdr,
    out eg_metadata_t               meta,
    
    out egress_intrinsic_metadata_t eg_intr_md
) {
    state start {
        pkt.extract(eg_intr_md);
        meta.egress_port = eg_intr_md.egress_port;
        transition parse_metadata;
    }

    state parse_metadata {
        pkt.extract(hdr.meta);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.AP4    : parse_active_ih;
            _                   : accept;
        }
    }

    state parse_active_ih {
        pkt.extract(hdr.ih);
        transition select(hdr.ih.flag_done) {
            1   : accept;
            _   : parse_active_args;
        }
    }

    state parse_active_args {
        pkt.extract(hdr.data);
        transition select(hdr.ih.opt_data) {
            1   : parse_active_data;
            _   : parse_active_instruction;
        }
    }

    state parse_active_data {
        //pkt.extract(hdr.bulk_data);
        transition parse_active_instruction;
    }

    state parse_active_instruction {
        pkt.extract(hdr.instr.next);
        transition select(hdr.instr.last.opcode) {
            0x0     : accept;
            _       : parse_active_instruction;
        }
    }
}

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    Mirror() mirror;
    apply {
        if(eg_dprsr_md.mirror_type == 1) {
            mirror.emit(meta.mirror_sessid);
        }
        pkt.emit(hdr);
    }
}