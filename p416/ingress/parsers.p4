parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
    Checksum() tcp_checksum;

    state start {
        pkt.extract(ig_intr_md);
        hdr.meta.setValid();
        transition select(ig_intr_md.resubmit_flag) {
            1   : parse_resubmit;
            0   : parse_port_metadata;
        }
    }

    state parse_resubmit {
        pkt.extract(meta.resubmit_data);
        hdr.meta.mbr2 = meta.resubmit_data.buf;
        hdr.meta.mar = meta.resubmit_data.addr;
        transition parse_ethernet;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ether_type_t.AP4    : parse_active_ih;
            ether_type_t.IPV4   : parse_ipv4;
            _                   : accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        tcp_checksum.subtract({ hdr.ipv4.src_addr, hdr.ipv4.dst_addr });
        transition select(hdr.ipv4.protocol) {
            ipv4_protocol_t.UDP : parse_udp;
            ipv4_protocol_t.TCP : parse_tcp;
            default             : accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dst_port) {
            active_port_t.UDP    : parse_active_ih;
            default : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        tcp_checksum.subtract({ hdr.tcp.checksum });
        tcp_checksum.subtract({ hdr.tcp.seq_no, hdr.tcp.ack_no });
        tcp_checksum.subtract({ hdr.tcp.flags });
        //tcp_checksum.subtract({ hdr.tcp.data_offset, hdr.tcp.res, hdr.tcp.ecn, hdr.tcp.ctrl });
        tcp_checksum.subtract_all_and_deposit(meta.chksum_tcp);
        transition accept;
        /*transition select(hdr.tcp.data_offset) {
            5..15   : parse_tcp_options;
            default : accept;
        }*/
    }

    /*state parse_tcp_options {
        pkt.extract(hdr.tcpopts, (bit<32>)(hdr.tcp.data_offset - 5) * 32);
        transition accept;
    }*/

    state parse_active_ih {
        pkt.extract(hdr.ih);
        hdr.meta.inc = 32w1;
        hdr.meta.fid = (bit<8>)hdr.ih.fid;
        transition check_alloc_req;
    }

    state check_alloc_req {
        transition select(hdr.ih.flag_reqalloc) {
            active_malloc_t.REQ : parse_malloc;
            active_malloc_t.GET : parse_ipv4;
            _                   : check_completion;  
        }
    }

    state parse_malloc {
        pkt.extract(hdr.malloc);
        transition parse_ipv4;
    }

    state check_completion {
        transition select(hdr.ih.flag_done) {
            1   : parse_ipv4;
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
            0x0     : parse_ipv4;
            _       : parse_active_instruction;
        }
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    Checksum() ipv4_checksum;
    Checksum() tcp_checksum;
    Resubmit() resubmit;
    Digest<malloc_digest_t>() malloc_digest;
    apply {
        if(ig_dprsr_md.resubmit_type == RESUBMIT_TYPE_DEFAULT) {
            resubmit.emit<resubmit_header_t>({
                hdr.meta.mbr2,
                hdr.meta.mar
            });
        }
        if(ig_dprsr_md.digest_type == 1) {
            malloc_digest.pack({
                hdr.ih.fid,
                hdr.malloc.proglen,
                hdr.malloc.iglim,
                hdr.malloc.mem_0,
                hdr.malloc.mem_1,
                hdr.malloc.mem_2,
                hdr.malloc.mem_3,
                hdr.malloc.mem_4,
                hdr.malloc.mem_5,
                hdr.malloc.mem_6,
                hdr.malloc.mem_7,
                hdr.malloc.dem_0,
                hdr.malloc.dem_1,
                hdr.malloc.dem_2,
                hdr.malloc.dem_3,
                hdr.malloc.dem_4,
                hdr.malloc.dem_5,
                hdr.malloc.dem_6,
                hdr.malloc.dem_7
            });
        }
        if(hdr.ipv4.isValid()) {
            hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            });
        }
        if(hdr.tcp.isValid()) {
            hdr.tcp.checksum = tcp_checksum.update({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.tcp.seq_no,
                hdr.tcp.ack_no,
                hdr.tcp.flags,
                meta.chksum_tcp
            });
        }
        pkt.emit(hdr);
    }
}