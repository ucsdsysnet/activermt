#ifndef IPV4_LPM_SIZE
    #define IPV4_LPM_SIZE (12 * 1024)
#endif

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