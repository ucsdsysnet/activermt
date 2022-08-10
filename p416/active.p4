#ifndef IPV4_LPM_SIZE
    #define IPV4_LPM_SIZE (12 * 1024)
#endif

typedef bit<8>  pkt_type_t;
const pkt_type_t PKT_TYPE_NORMAL = 1;
const pkt_type_t PKT_TYPE_MIRROR = 2;

#if __TARGET_TOFINO__ == 1
typedef bit<3> mirror_type_t;
#else
typedef bit<4> mirror_type_t;
#endif

const mirror_type_t MIRROR_TYPE_I2E = 1;
const mirror_type_t MIRROR_TYPE_E2E = 2;

#define RESUBMIT_TYPE_DEFAULT   1

#define MAX_INSTRUCTIONS        21
#define MAX_TCP_OPTIONS         10
#define CONST_SALT              0x5093

#include <core.p4>
#include <tna.p4>

#include "headers.p4"
#include "ingress/parsers.p4"
#include "ingress/control.p4"
#include "egress/parsers.p4"
#include "egress/control.p4"

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;