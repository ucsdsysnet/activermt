#ifdef __TARGET_TOFINO__
#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>
#include <tofino/primitives.p4>
#include <tofino/stateful_alu_blackbox.p4>
#else
#error This program is intended to compile for Tofino P4 architecture only
#endif

#include "headers.p4"
#include "parsers.p4"
#include "hashing.p4"
#include "memory.p4"
#include "ingress/malloc.p4"
#include "ingress/bwmonitor.p4"
#include "ingress/resources.p4"
#include "ingress/forwarding.p4"
#include "egress/actions/generic.p4"
#include "egress/actions/stagewise.p4"
#include "egress/progress.p4"
#include "egress/execution.p4"
#include "egress/recirculation.p4"

#define FLAG_NONE       0
#define FLAG_REDIRECT   1
#define FLAG_IGCLONE    2
#define FLAG_BYPASS     3
#define FLAG_RTS        5
#define FLAG_GC         6
#define FLAG_AUX        8
#define FLAG_ACK        255

header ethernet_t           ethernet;
header ipv4_t               ipv4;
header udp_t                udp;
header tcp_t                tcp;
header pktgen_ts_t          ts;
header active_state_t       as;

header active_program_t     ap[14];

header tcp_option_4B_t          tcpo_4b;
header tcp_option_8B_t          tcpo_8b;
header tcp_option_12B_t         tcpo_12b;
header tcp_option_16B_t         tcpo_16b;
header tcp_option_20B_t         tcpo_20b;
header tcp_option_24B_t         tcpo_24b;
header tcp_option_28B_t         tcpo_28b;
header tcp_option_32B_t         tcpo_32b;
header tcp_option_36B_t         tcpo_36b;
header tcp_option_40B_t         tcpo_40b;

metadata metadata_t         meta;

////////////////// [INGRESS] //////////////////

action preload_mbr() {
    modify_field(meta.mbr, as.acc2);
}

table preload {
    reads {
        as.flag_exceeded    : exact;
    }
    actions {
        preload_mbr;
    }
}

control ingress {
    apply(ig_traffic_counter);
    if(valid(as)) {
        apply(preload);
        apply(check_completion) {
            miss {
                apply(preplimit);
                apply(resources) {
                    hit {
                        if(as.flag_usecache == 1) {
    					apply(cached_1);
						apply(cached_2);
						apply(cached_3);
						apply(cached_4);
						apply(cached_5);
						apply(cached_6);
                        } else {
    					apply(proceed_1);
						apply(execute_1);
						apply(proceed_2);
						apply(execute_2);
						apply(proceed_3);
						apply(execute_3);
						apply(proceed_4);
						apply(execute_4);
						apply(proceed_5);
						apply(execute_5);
						apply(proceed_6);
						apply(execute_6);                        
                        }
                    }
                }
            }
        }
        /*apply(check_alloc_status);
        apply(memalloc) {
            miss {
                apply(getalloc);
            }
        }*/
        apply(getalloc);
        apply(getbw);
        apply(fwdparams);
        apply(backward);
    } else {
        apply(forward);
    }
}

/////////////////// [EGRESS] //////////////////

counter recirc {
    type            : packets;
    instance_count  : 1;
}

action loopback() {
    modify_field(meta.mirror_type, 1);
    modify_field(meta.mirror_sess, meta.fwdid);
    clone_egress_pkt_to_egress(meta.fwdid, cycle_metadata);
    modify_field(eg_intr_md_for_oport.drop_ctl, 1);
    subtract_from_field(ipv4.ttl, 1);
    count(recirc, 0);
}

table bwgen {
    reads {
        ipv4.ttl    : range;
    }
    actions {
        loopback;
    }
}

control egress {
    apply(generic_traffic_monitor);
    if(valid(as)) {
        apply(active_traffic_counter);
        if(as.flag_usecache == 1) {
    	apply(cached_7);
		apply(cached_8);
		apply(cached_9);
		apply(cached_10);
		apply(cached_11);
		apply(cached_12);
		apply(cached_13);
		apply(cached_14);
        } else {
    	apply(proceed_7);
		apply(execute_7);
		apply(proceed_8);
		apply(execute_8);
		apply(proceed_9);
		apply(execute_9);
		apply(proceed_10);
		apply(execute_10);
		apply(proceed_11);
		apply(execute_11);
		apply(proceed_12);
		apply(execute_12);
		apply(proceed_13);
		apply(execute_13);
		apply(proceed_14);
		apply(execute_14);        
        }
        apply(cycleupdate);
        apply(progress);
        apply(lenupdate);
    } else {
        apply(bwgen);
    }
}