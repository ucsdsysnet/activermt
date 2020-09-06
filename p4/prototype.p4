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
header active_program_t     ap[11];

//@pragma pa_atomic egress meta.mirror_sess
metadata metadata_t         meta;

////////////////// [INGRESS] //////////////////

control ingress {
    /*apply(checkgc) {
        miss {
            apply(resources);
            apply(forward);
            apply(backward);
            apply(check_completion);
        }
    }
    apply(measure_freq);
    apply(filter);*/
    apply(check_alloc_status);
    apply(memalloc) {
        miss {
            apply(getalloc);
        }
    }
    apply(resources);
    apply(filter_meter);
    apply(monitor);
    apply(forward);
    apply(backward);
    apply(check_completion);
}

/////////////////// [EGRESS] //////////////////

control egress {
    apply(proceed_1);
	apply(execute_1) { hit {
		apply(proceed_2);
		apply(execute_2) { hit {
			apply(proceed_3);
			apply(execute_3) { hit {
				apply(proceed_4);
				apply(execute_4) { hit {
					apply(proceed_5);
					apply(execute_5) { hit {
						apply(proceed_6);
						apply(execute_6) { hit {
							apply(proceed_7);
							apply(execute_7) { hit {
								apply(proceed_8);
								apply(execute_8) { hit {
									apply(proceed_9);
									apply(execute_9) { hit {
										apply(proceed_10);
										apply(execute_10) { hit {
											apply(proceed_11);
											apply(execute_11) { hit {
											}}
										}}
									}}
								}}
							}}
						}}
					}}
				}}
			}}
		}}
	}}
    apply(cycleupdate);
    apply(progress);
    apply(lenupdate);
}