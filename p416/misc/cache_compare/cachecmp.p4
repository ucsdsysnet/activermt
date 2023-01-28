#include <core.p4>
#include <tna.p4>

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

header cache_selector_h {
    bit<16>     fid;
}

header cache_0_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_1_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_2_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_3_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_4_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_5_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_6_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_7_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_8_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_9_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

header cache_10_h {
    bit<32>     addr;
    bit<32>     key;
    bit<32>     value;
}

struct ig_metadata_t {
    bit<32>	key_0;
	bit<32>	key_1;
	bit<32>	key_2;
	bit<32>	key_3;
	bit<32>	key_4;
	bit<32>	key_5;
	bit<32>	key_6;
	bit<32>	key_7;
	bit<32>	key_8;
	bit<32>	key_9;
	bit<32>	key_10;
}

struct eg_metadata_t {
    bit<32>	key_0;
	bit<32>	key_1;
	bit<32>	key_2;
	bit<32>	key_3;
	bit<32>	key_4;
	bit<32>	key_5;
	bit<32>	key_6;
	bit<32>	key_7;
	bit<32>	key_8;
	bit<32>	key_9;
	bit<32>	key_10;
}

struct ingress_headers_t {
    ethernet_h              ethernet;
    cache_selector_h        cache_selector;
    cache_0_h				cache_0;
	cache_1_h				cache_1;
	cache_2_h				cache_2;
	cache_3_h				cache_3;
	cache_4_h				cache_4;
	cache_5_h				cache_5;
	cache_6_h				cache_6;
	cache_7_h				cache_7;
	cache_8_h				cache_8;
	cache_9_h				cache_9;
	cache_10_h				cache_10;                  
}

struct egress_headers_t {
    ethernet_h              ethernet;
    cache_selector_h        cache_selector;
    cache_0_h				cache_0;
	cache_1_h				cache_1;
	cache_2_h				cache_2;
	cache_3_h				cache_3;
	cache_4_h				cache_4;
	cache_5_h				cache_5;
	cache_6_h				cache_6;
	cache_7_h				cache_7;
	cache_8_h				cache_8;
	cache_9_h				cache_9;
	cache_10_h				cache_10;
}

parser IngressParser(
    packet_in                       pkt,
    out ingress_headers_t           hdr,
    out ig_metadata_t               meta,
    
    out ingress_intrinsic_metadata_t    ig_intr_md
) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition parse_cache_selector;
    }

    state parse_cache_selector {
        pkt.extract(hdr.cache_selector);
        transition select(hdr.cache_selector.fid) {
            0	: parse_cache_0;
			1	: parse_cache_1;
			2	: parse_cache_2;
			3	: parse_cache_3;
			4	: parse_cache_4;
			5	: parse_cache_5;
			6	: parse_cache_6;
			7	: parse_cache_7;
			8	: parse_cache_8;
			9	: parse_cache_9;
			10	: parse_cache_10;
            _   : accept;
        }
    }

    state parse_cache_0 {
	    pkt.extract(hdr.cache_0);
	    transition accept;
	}

	state parse_cache_1 {
	    pkt.extract(hdr.cache_1);
	    transition accept;
	}

	state parse_cache_2 {
	    pkt.extract(hdr.cache_2);
	    transition accept;
	}

	state parse_cache_3 {
	    pkt.extract(hdr.cache_3);
	    transition accept;
	}

	state parse_cache_4 {
	    pkt.extract(hdr.cache_4);
	    transition accept;
	}

	state parse_cache_5 {
	    pkt.extract(hdr.cache_5);
	    transition accept;
	}

	state parse_cache_6 {
	    pkt.extract(hdr.cache_6);
	    transition accept;
	}

	state parse_cache_7 {
	    pkt.extract(hdr.cache_7);
	    transition accept;
	}

	state parse_cache_8 {
	    pkt.extract(hdr.cache_8);
	    transition accept;
	}

	state parse_cache_9 {
	    pkt.extract(hdr.cache_9);
	    transition accept;
	}

	state parse_cache_10 {
	    pkt.extract(hdr.cache_10);
	    transition accept;
	}
}

control Ingress(
    inout ingress_headers_t                          hdr,
    inout ig_metadata_t                              meta,
    
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md
) {
    @stage(0)
	Register<bit<32>, bit<32>>(32w45056) heap_0_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_0_key) heap_0_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_0_read_key() {
	    meta.key_0 = heap_0_read_key.execute(hdr.cache_0.addr);
	}
	
	@stage(0)
	Register<bit<32>, bit<32>>(32w45056) heap_0_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_0_value) heap_0_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_0_read_value() {
	    hdr.cache_0.value = heap_0_read_value.execute(hdr.cache_0.addr);
	}
	@stage(1)
	Register<bit<32>, bit<32>>(32w45056) heap_1_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_1_key) heap_1_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_1_read_key() {
	    meta.key_1 = heap_1_read_key.execute(hdr.cache_1.addr);
	}
	
	@stage(1)
	Register<bit<32>, bit<32>>(32w45056) heap_1_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_1_value) heap_1_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_1_read_value() {
	    hdr.cache_1.value = heap_1_read_value.execute(hdr.cache_1.addr);
	}
	@stage(2)
	Register<bit<32>, bit<32>>(32w45056) heap_2_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_2_key) heap_2_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_2_read_key() {
	    meta.key_2 = heap_2_read_key.execute(hdr.cache_2.addr);
	}
	
	@stage(2)
	Register<bit<32>, bit<32>>(32w45056) heap_2_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_2_value) heap_2_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_2_read_value() {
	    hdr.cache_2.value = heap_2_read_value.execute(hdr.cache_2.addr);
	}
	@stage(3)
	Register<bit<32>, bit<32>>(32w45056) heap_3_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_3_key) heap_3_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_3_read_key() {
	    meta.key_3 = heap_3_read_key.execute(hdr.cache_3.addr);
	}
	
	@stage(3)
	Register<bit<32>, bit<32>>(32w45056) heap_3_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_3_value) heap_3_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_3_read_value() {
	    hdr.cache_3.value = heap_3_read_value.execute(hdr.cache_3.addr);
	}
	@stage(4)
	Register<bit<32>, bit<32>>(32w45056) heap_4_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_4_key) heap_4_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_4_read_key() {
	    meta.key_4 = heap_4_read_key.execute(hdr.cache_4.addr);
	}
	
	@stage(4)
	Register<bit<32>, bit<32>>(32w45056) heap_4_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_4_value) heap_4_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_4_read_value() {
	    hdr.cache_4.value = heap_4_read_value.execute(hdr.cache_4.addr);
	}
	@stage(5)
	Register<bit<32>, bit<32>>(32w45056) heap_5_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_5_key) heap_5_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_5_read_key() {
	    meta.key_5 = heap_5_read_key.execute(hdr.cache_5.addr);
	}
	
	@stage(5)
	Register<bit<32>, bit<32>>(32w45056) heap_5_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_5_value) heap_5_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_5_read_value() {
	    hdr.cache_5.value = heap_5_read_value.execute(hdr.cache_5.addr);
	}
	@stage(6)
	Register<bit<32>, bit<32>>(32w45056) heap_6_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_6_key) heap_6_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_6_read_key() {
	    meta.key_6 = heap_6_read_key.execute(hdr.cache_6.addr);
	}
	
	@stage(6)
	Register<bit<32>, bit<32>>(32w45056) heap_6_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_6_value) heap_6_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_6_read_value() {
	    hdr.cache_6.value = heap_6_read_value.execute(hdr.cache_6.addr);
	}
	@stage(7)
	Register<bit<32>, bit<32>>(32w45056) heap_7_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_7_key) heap_7_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_7_read_key() {
	    meta.key_7 = heap_7_read_key.execute(hdr.cache_7.addr);
	}
	
	@stage(7)
	Register<bit<32>, bit<32>>(32w45056) heap_7_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_7_value) heap_7_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_7_read_value() {
	    hdr.cache_7.value = heap_7_read_value.execute(hdr.cache_7.addr);
	}
	@stage(8)
	Register<bit<32>, bit<32>>(32w45056) heap_8_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_8_key) heap_8_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_8_read_key() {
	    meta.key_8 = heap_8_read_key.execute(hdr.cache_8.addr);
	}
	
	@stage(8)
	Register<bit<32>, bit<32>>(32w45056) heap_8_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_8_value) heap_8_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_8_read_value() {
	    hdr.cache_8.value = heap_8_read_value.execute(hdr.cache_8.addr);
	}
	@stage(9)
	Register<bit<32>, bit<32>>(32w45056) heap_9_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_9_key) heap_9_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_9_read_key() {
	    meta.key_9 = heap_9_read_key.execute(hdr.cache_9.addr);
	}
	
	@stage(9)
	Register<bit<32>, bit<32>>(32w45056) heap_9_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_9_value) heap_9_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_9_read_value() {
	    hdr.cache_9.value = heap_9_read_value.execute(hdr.cache_9.addr);
	}
	@stage(10)
	Register<bit<32>, bit<32>>(32w45056) heap_10_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_10_key) heap_10_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_10_read_key() {
	    meta.key_10 = heap_10_read_key.execute(hdr.cache_10.addr);
	}
	
	@stage(10)
	Register<bit<32>, bit<32>>(32w45056) heap_10_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_10_value) heap_10_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_10_read_value() {
	    hdr.cache_10.value = heap_10_read_value.execute(hdr.cache_10.addr);
	}

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
        ig_tm_md.bypass_egress = 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action rts() {
        mac_addr_t tmp;
        tmp = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
        hdr.ethernet.src_addr = tmp;
    }

    table fwd {
        key     = {
            hdr.ethernet.dst_addr   : exact;
        }
        actions = {
            send;
            drop;
        }
        const default_action = drop();
        size = 8096;
    }

    apply {
        if(hdr.ethernet.isValid()) {
            fwd.apply();
        }
        if(hdr.cache_0.isValid()) { memory_0_read_key(); if(meta.key_0 == hdr.cache_0.key) memory_0_read_value(); }
		if(hdr.cache_1.isValid()) { memory_1_read_key(); if(meta.key_1 == hdr.cache_1.key) memory_1_read_value(); }
		if(hdr.cache_2.isValid()) { memory_2_read_key(); if(meta.key_2 == hdr.cache_2.key) memory_2_read_value(); }
		if(hdr.cache_3.isValid()) { memory_3_read_key(); if(meta.key_3 == hdr.cache_3.key) memory_3_read_value(); }
		if(hdr.cache_4.isValid()) { memory_4_read_key(); if(meta.key_4 == hdr.cache_4.key) memory_4_read_value(); }
		if(hdr.cache_5.isValid()) { memory_5_read_key(); if(meta.key_5 == hdr.cache_5.key) memory_5_read_value(); }
		if(hdr.cache_6.isValid()) { memory_6_read_key(); if(meta.key_6 == hdr.cache_6.key) memory_6_read_value(); }
		if(hdr.cache_7.isValid()) { memory_7_read_key(); if(meta.key_7 == hdr.cache_7.key) memory_7_read_value(); }
		if(hdr.cache_8.isValid()) { memory_8_read_key(); if(meta.key_8 == hdr.cache_8.key) memory_8_read_value(); }
		if(hdr.cache_9.isValid()) { memory_9_read_key(); if(meta.key_9 == hdr.cache_9.key) memory_9_read_value(); }
		if(hdr.cache_10.isValid()) { memory_10_read_key(); if(meta.key_10 == hdr.cache_10.key) memory_10_read_value(); }
    }
}

control IngressDeparser(
    packet_out                      pkt,
    inout ingress_headers_t         hdr,
    in    ig_metadata_t             meta,
    
    in    ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
) {
    apply {
        pkt.emit(hdr);
    }
}

parser EgressParser(
    packet_in                       pkt,
    out egress_headers_t            hdr,
    out eg_metadata_t               meta,
    
    out egress_intrinsic_metadata_t eg_intr_md
) {
    state start {
        pkt.extract(eg_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition parse_cache_selector;
    }

    state parse_cache_selector {
        pkt.extract(hdr.cache_selector);
        transition select(hdr.cache_selector.fid) {
            0	: parse_cache_0;
			1	: parse_cache_1;
			2	: parse_cache_2;
			3	: parse_cache_3;
			4	: parse_cache_4;
			5	: parse_cache_5;
			6	: parse_cache_6;
			7	: parse_cache_7;
			8	: parse_cache_8;
			9	: parse_cache_9;
			10	: parse_cache_10;
            _   : accept;
        }
    }

    state parse_cache_0 {
	    pkt.extract(hdr.cache_0);
	    transition accept;
	}

	state parse_cache_1 {
	    pkt.extract(hdr.cache_1);
	    transition accept;
	}

	state parse_cache_2 {
	    pkt.extract(hdr.cache_2);
	    transition accept;
	}

	state parse_cache_3 {
	    pkt.extract(hdr.cache_3);
	    transition accept;
	}

	state parse_cache_4 {
	    pkt.extract(hdr.cache_4);
	    transition accept;
	}

	state parse_cache_5 {
	    pkt.extract(hdr.cache_5);
	    transition accept;
	}

	state parse_cache_6 {
	    pkt.extract(hdr.cache_6);
	    transition accept;
	}

	state parse_cache_7 {
	    pkt.extract(hdr.cache_7);
	    transition accept;
	}

	state parse_cache_8 {
	    pkt.extract(hdr.cache_8);
	    transition accept;
	}

	state parse_cache_9 {
	    pkt.extract(hdr.cache_9);
	    transition accept;
	}

	state parse_cache_10 {
	    pkt.extract(hdr.cache_10);
	    transition accept;
	}
}

control Egress(
    inout egress_headers_t                             hdr,
    inout eg_metadata_t                                meta,
    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md
) {
    @stage(0)
	Register<bit<32>, bit<32>>(32w45056) heap_0_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_0_key) heap_0_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_0_read_key() {
	    meta.key_0 = heap_0_read_key.execute(hdr.cache_0.addr);
	}
	
	@stage(0)
	Register<bit<32>, bit<32>>(32w45056) heap_0_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_0_value) heap_0_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_0_read_value() {
	    hdr.cache_0.value = heap_0_read_value.execute(hdr.cache_0.addr);
	}
	@stage(1)
	Register<bit<32>, bit<32>>(32w45056) heap_1_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_1_key) heap_1_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_1_read_key() {
	    meta.key_1 = heap_1_read_key.execute(hdr.cache_1.addr);
	}
	
	@stage(1)
	Register<bit<32>, bit<32>>(32w45056) heap_1_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_1_value) heap_1_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_1_read_value() {
	    hdr.cache_1.value = heap_1_read_value.execute(hdr.cache_1.addr);
	}
	@stage(2)
	Register<bit<32>, bit<32>>(32w45056) heap_2_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_2_key) heap_2_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_2_read_key() {
	    meta.key_2 = heap_2_read_key.execute(hdr.cache_2.addr);
	}
	
	@stage(2)
	Register<bit<32>, bit<32>>(32w45056) heap_2_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_2_value) heap_2_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_2_read_value() {
	    hdr.cache_2.value = heap_2_read_value.execute(hdr.cache_2.addr);
	}
	@stage(3)
	Register<bit<32>, bit<32>>(32w45056) heap_3_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_3_key) heap_3_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_3_read_key() {
	    meta.key_3 = heap_3_read_key.execute(hdr.cache_3.addr);
	}
	
	@stage(3)
	Register<bit<32>, bit<32>>(32w45056) heap_3_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_3_value) heap_3_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_3_read_value() {
	    hdr.cache_3.value = heap_3_read_value.execute(hdr.cache_3.addr);
	}
	@stage(4)
	Register<bit<32>, bit<32>>(32w45056) heap_4_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_4_key) heap_4_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_4_read_key() {
	    meta.key_4 = heap_4_read_key.execute(hdr.cache_4.addr);
	}
	
	@stage(4)
	Register<bit<32>, bit<32>>(32w45056) heap_4_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_4_value) heap_4_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_4_read_value() {
	    hdr.cache_4.value = heap_4_read_value.execute(hdr.cache_4.addr);
	}
	@stage(5)
	Register<bit<32>, bit<32>>(32w45056) heap_5_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_5_key) heap_5_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_5_read_key() {
	    meta.key_5 = heap_5_read_key.execute(hdr.cache_5.addr);
	}
	
	@stage(5)
	Register<bit<32>, bit<32>>(32w45056) heap_5_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_5_value) heap_5_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_5_read_value() {
	    hdr.cache_5.value = heap_5_read_value.execute(hdr.cache_5.addr);
	}
	@stage(6)
	Register<bit<32>, bit<32>>(32w45056) heap_6_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_6_key) heap_6_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_6_read_key() {
	    meta.key_6 = heap_6_read_key.execute(hdr.cache_6.addr);
	}
	
	@stage(6)
	Register<bit<32>, bit<32>>(32w45056) heap_6_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_6_value) heap_6_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_6_read_value() {
	    hdr.cache_6.value = heap_6_read_value.execute(hdr.cache_6.addr);
	}
	@stage(7)
	Register<bit<32>, bit<32>>(32w45056) heap_7_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_7_key) heap_7_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_7_read_key() {
	    meta.key_7 = heap_7_read_key.execute(hdr.cache_7.addr);
	}
	
	@stage(7)
	Register<bit<32>, bit<32>>(32w45056) heap_7_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_7_value) heap_7_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_7_read_value() {
	    hdr.cache_7.value = heap_7_read_value.execute(hdr.cache_7.addr);
	}
	@stage(8)
	Register<bit<32>, bit<32>>(32w45056) heap_8_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_8_key) heap_8_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_8_read_key() {
	    meta.key_8 = heap_8_read_key.execute(hdr.cache_8.addr);
	}
	
	@stage(8)
	Register<bit<32>, bit<32>>(32w45056) heap_8_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_8_value) heap_8_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_8_read_value() {
	    hdr.cache_8.value = heap_8_read_value.execute(hdr.cache_8.addr);
	}
	@stage(9)
	Register<bit<32>, bit<32>>(32w45056) heap_9_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_9_key) heap_9_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_9_read_key() {
	    meta.key_9 = heap_9_read_key.execute(hdr.cache_9.addr);
	}
	
	@stage(9)
	Register<bit<32>, bit<32>>(32w45056) heap_9_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_9_value) heap_9_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_9_read_value() {
	    hdr.cache_9.value = heap_9_read_value.execute(hdr.cache_9.addr);
	}
	@stage(10)
	Register<bit<32>, bit<32>>(32w45056) heap_10_key;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_10_key) heap_10_read_key = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_10_read_key() {
	    meta.key_10 = heap_10_read_key.execute(hdr.cache_10.addr);
	}
	
	@stage(10)
	Register<bit<32>, bit<32>>(32w45056) heap_10_value;
	
	RegisterAction<bit<32>, bit<32>, bit<32>>(heap_10_value) heap_10_read_value = {
	    void apply(inout bit<32> value, out bit<32> rv) {
	        rv = value;
	    }
	};
	
	action memory_10_read_value() {
	    hdr.cache_10.value = heap_10_read_value.execute(hdr.cache_10.addr);
	}
    
    apply {
        if(hdr.cache_0.isValid()) { memory_0_read_key(); if(meta.key_0 == hdr.cache_0.key) memory_0_read_value(); }
		if(hdr.cache_1.isValid()) { memory_1_read_key(); if(meta.key_1 == hdr.cache_1.key) memory_1_read_value(); }
		if(hdr.cache_2.isValid()) { memory_2_read_key(); if(meta.key_2 == hdr.cache_2.key) memory_2_read_value(); }
		if(hdr.cache_3.isValid()) { memory_3_read_key(); if(meta.key_3 == hdr.cache_3.key) memory_3_read_value(); }
		if(hdr.cache_4.isValid()) { memory_4_read_key(); if(meta.key_4 == hdr.cache_4.key) memory_4_read_value(); }
		if(hdr.cache_5.isValid()) { memory_5_read_key(); if(meta.key_5 == hdr.cache_5.key) memory_5_read_value(); }
		if(hdr.cache_6.isValid()) { memory_6_read_key(); if(meta.key_6 == hdr.cache_6.key) memory_6_read_value(); }
		if(hdr.cache_7.isValid()) { memory_7_read_key(); if(meta.key_7 == hdr.cache_7.key) memory_7_read_value(); }
		if(hdr.cache_8.isValid()) { memory_8_read_key(); if(meta.key_8 == hdr.cache_8.key) memory_8_read_value(); }
		if(hdr.cache_9.isValid()) { memory_9_read_key(); if(meta.key_9 == hdr.cache_9.key) memory_9_read_value(); }
		if(hdr.cache_10.isValid()) { memory_10_read_key(); if(meta.key_10 == hdr.cache_10.key) memory_10_read_value(); }
    }
}

control EgressDeparser(
    packet_out                      pkt,
    inout egress_headers_t          hdr,
    in    eg_metadata_t             meta,
    
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md
) {
    apply {
        pkt.emit(hdr);
    }
}

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;