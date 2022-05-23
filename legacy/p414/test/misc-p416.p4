#include <core.p4>
#include <tofino.p4>
#include <tofino1arch.p4>

struct compiler_generated_metadata_t {
    bit<10> mirror_id;
    bit<8>  mirror_source;
    bit<8>  resubmit_source;
    bit<4>  clone_src;
    bit<4>  clone_digest_id;
    bit<32> instance_type;
}

struct metadata_t {
    bit<16> result;
}

struct standard_metadata_t {
    bit<9>  ingress_port;
    bit<32> packet_length;
    bit<9>  egress_spec;
    bit<9>  egress_port;
    bit<16> egress_instance;
    bit<32> instance_type;
    bit<8>  parser_status;
    bit<8>  parser_error_location;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

@name("generator_metadata_t") header generator_metadata_t_0 {
    bit<16> app_id;
    bit<16> batch_id;
    bit<16> instance_id;
}

struct metadata {
    @name(".__bfp4c_compiler_generated_meta") 
    compiler_generated_metadata_t               __bfp4c_compiler_generated_meta;
    @name(".eg_intr_md") 
    egress_intrinsic_metadata_t                 eg_intr_md;
    @name(".eg_intr_md_for_dprsr") 
    egress_intrinsic_metadata_for_deparser_t    eg_intr_md_for_dprsr;
    @name(".eg_intr_md_for_oport") 
    egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport;
    @name(".eg_intr_md_from_parser_aux") 
    egress_intrinsic_metadata_from_parser_t     eg_intr_md_from_parser_aux;
    @name(".ig_intr_md") 
    ingress_intrinsic_metadata_t                ig_intr_md;
    @name(".ig_intr_md_for_tm") 
    ingress_intrinsic_metadata_for_tm_t         ig_intr_md_for_tm;
    @name(".ig_intr_md_from_parser_aux") 
    ingress_intrinsic_metadata_from_parser_t    ig_intr_md_from_parser_aux;
    @name(".meta") 
    metadata_t                                  meta;
    @name(".standard_metadata") 
    standard_metadata_t                         standard_metadata;
}

struct headers {
    @name(".ethernet") 
    ethernet_t ethernet;
}

parser IngressParserImpl(packet_in pkt, out headers hdr, out metadata meta, out ingress_intrinsic_metadata_t ig_intr_md, out ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, out ingress_intrinsic_metadata_from_parser_t ig_intr_md_from_prsr) {
    @name("start") state __ingress_p4_entry_point {
        pkt.extract(hdr.ethernet);
        transition accept;
    }
    @name("$skip_to_packet") state __skip_to_packet {
        pkt.advance(32w0);
        transition __ingress_p4_entry_point;
    }
    @name("$phase0") state __phase0 {
        pkt.advance(32w64);
        transition __skip_to_packet;
    }
    @name("$resubmit") state __resubmit {
        transition __ingress_p4_entry_point;
    }
    @name("$check_resubmit") state __check_resubmit {
        transition select(ig_intr_md.resubmit_flag) {
            1w0 &&& 1w1: __phase0;
            1w1 &&& 1w1: __resubmit;
        }
    }
    @name("$ingress_metadata") state __ingress_metadata {
        pkt.extract<ingress_intrinsic_metadata_t>(ig_intr_md);
        transition __check_resubmit;
    }
    @name("$ingress_tna_entry_point") state start {
        transition __ingress_metadata;
    }
}

parser EgressParserImpl(packet_in pkt, out headers hdr, out metadata meta, out egress_intrinsic_metadata_t eg_intr_md, out egress_intrinsic_metadata_from_parser_t eg_intr_md_from_parser_aux) {
    @name("start") state __egress_p4_entry_point {
        pkt.extract(hdr.ethernet);
        transition accept;
    }
    @name("$bridged_metadata") state __bridged_metadata {
        transition __egress_p4_entry_point;
    }
    @name("$mirrored") state __mirrored {
        transition __egress_p4_entry_point;
    }
    @name("$check_mirrored") state __check_mirrored {
        transition select(pkt.lookahead<bit<8>>()) {
            8w0 &&& 8w8: __bridged_metadata;
            8w8 &&& 8w8: __mirrored;
        }
    }
    @name("$egress_metadata") state __egress_metadata {
        pkt.extract<egress_intrinsic_metadata_t>(eg_intr_md);
        transition __check_mirrored;
    }
    @name("$egress_tna_entry_point") state start {
        transition __egress_metadata;
    }
}

control egress(inout headers hdr, inout metadata meta, in egress_intrinsic_metadata_t eg_intr_md, in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_parser_aux, inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr, inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {
    apply {
    }
}

control ingress(inout headers hdr, inout metadata meta, in ingress_intrinsic_metadata_t ig_intr_md, in ingress_intrinsic_metadata_from_parser_t ig_intr_md_from_parser_aux, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    @name(".compute") action compute() {
        meta.meta.result = (meta.meta.result <= hdr.ethernet.etherType ? meta.meta.result : hdr.ethernet.etherType);
    }
    @name(".dummy") table dummy {
        actions = {
            compute();
            @defaultonly NoAction();
        }
        key = {
            hdr.ethernet.srcAddr: exact;
        }
        default_action = NoAction();
    }
    apply {
        dummy.apply();
    }
}

control IngressDeparserImpl(packet_out pkt, inout headers hdr, in metadata meta, in ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, in ingress_intrinsic_metadata_t ig_intr_md) {
    apply {
        pkt.emit(hdr.ethernet);
    }
}

control EgressDeparserImpl(packet_out pkt, inout headers hdr, in metadata meta, in egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr, in egress_intrinsic_metadata_t eg_intr_md, in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_parser_aux) {
    apply {
        pkt.emit(hdr.ethernet);
    }
}

Pipeline(IngressParserImpl(), ingress(), IngressDeparserImpl(), EgressParserImpl(), egress(), EgressDeparserImpl()) pipe;

@pa_auto_init_metadata Switch(pipe) main;

