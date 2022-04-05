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
header pktgen_ts_t          ts;
header active_state_t       as;
header active_program_t     ap[#numsteps];

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
    #precacheig
                        } else {
    #igtables                        
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
    #precacheeg
        } else {
    #tables        
        }
        apply(cycleupdate);
        apply(progress);
        apply(lenupdate);
    } else {
        apply(bwgen);
    }
}