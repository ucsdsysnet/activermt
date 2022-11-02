#ifndef CONTROLLER_COMMON_H
#define CONTROLLER_COMMON_H

#include <bf_rt/bf_rt.hpp>
#include <bf_rt/bf_rt_info.hpp>
#include <bf_rt/bf_rt_init.hpp>
#include <bf_rt/bf_rt_common.h>

#define ALL_PIPES       0xFFFF

static const char* p4_program_name      = "active";
bf_rt_target_t dev_tgt                  = {0, ALL_PIPES};

typedef struct {
    const bfrt::BfRtInfo*                   bfrtInfo;
    std::shared_ptr<bfrt::BfRtSession>      session;
    std::unique_ptr<bfrt::BfRtTableKey>     bfrtTableKey;
    std::unique_ptr<bfrt::BfRtTableData>    bfrtTableData;
} program_context_t;

#endif