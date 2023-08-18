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

#define MAX_INSTRUCTIONS        32
#define MAX_EXTENDED_DATA       8
#define MAX_TCP_OPTIONS         10
#define CONST_SALT              0x5093
#define MAX_RECIRCULATIONS      10
#define NUM_IG_STAGES           10
#define NUM_STAGES              20

#define EG_STAGE_OFFSET(X)      X + NUM_IG_STAGES

#include <core.p4>
#include <tna.p4>

#include "headers.p4"
#include "ingress/parsers.p4"
#include "ingress/control.p4"
#include "egress/parsers.p4"
#include "egress/control.p4"

@PA_no_overlay("egress", "eg_dprsr_md.drop_ctl")

Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;