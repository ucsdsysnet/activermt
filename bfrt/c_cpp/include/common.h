#ifndef COMMON_H
#define COMMON_H

extern "C" {
    #include <bf_rt/bf_rt.h>
    #include <bfsys/bf_sal/bf_sys_intf.h>
    #include <bf_switchd/bf_switchd.h>
}

#include <bf_rt/bf_rt.hpp>
#include <bf_rt/bf_rt_info.hpp>
#include <bf_rt/bf_rt_init.hpp>
#include <bf_rt/bf_rt_common.h>
#include <bf_rt/bf_rt_table_key.hpp>
#include <bf_rt/bf_rt_table_data.hpp>
#include <bf_rt/bf_rt_table.hpp>
#include <bf_rt/bf_rt_table_operations.hpp>
#include <dvm/bf_drv_intf.h>

#include <unistd.h>

#include "utils.h"

#define MAX_KEYLEN      64
#define MAX_MATCHKEYS   16
#define MAX_ACTIONDATA  8
#define MAXMEM          94207
#define MAXINSTANCES    368
#define GRANULARITY     256
#define OPEOF           0
#define NUM_STAGES_PIPE 10

#define ALL_PIPES       0xFFFF

const std::string program_name = "active";
const bfrt::BfRtInfo* bfrtInfo = nullptr;
static bf_switchd_context_t *switchd_ctx = NULL;
static int is_running = 0;
static bf_rt_target_t dev_tgt;

/**
 * @brief Memory region.
 * 
 */
typedef struct {
    int fid;
    int stage_id;
    int mem_start;
    int mem_end;
} active_malloc_blk_t;

/**
 * @brief Initialized the switch.
 * 
 */
void init_switchd() {

    std::string install_dir = getenv("SDE_INSTALL");
    std::string config_file = install_dir + "/share/p4/targets/tofino/" + program_name + ".conf";

    assertm(!install_dir.empty(), "SDE_INSTALL variable not set.\n");
    assertm(access(config_file.c_str(), F_OK) == 0, "Unable to access P4 program configuration file.\n");

    printf("Using SDE path: %s\n", install_dir.c_str());
    printf("Using config: %s\n", config_file.c_str());

    switchd_ctx = (bf_switchd_context_t *)calloc(1, sizeof(bf_switchd_context_t));
    if(!switchd_ctx) {
        printf("Unable to allocate switchd context.\n");
        exit(1);
    }

    // switchd_ctx->init_mode = BF_DEV_WARM_INIT_FAST_RECFG;
    switchd_ctx->init_mode = BF_DEV_INIT_COLD;
    switchd_ctx->running_in_background = true;
    switchd_ctx->skip_port_add = true;
    switchd_ctx->install_dir = (char*)install_dir.c_str();
    switchd_ctx->conf_file = (char*)config_file.c_str();

    auto bf_status = bf_switchd_lib_init(switchd_ctx);
    if(bf_status != BF_SUCCESS) {
        printf("Failed to initialize libbf_switchd (%s)\n", bf_err_str(bf_status));
        free(switchd_ctx);
        exit(1);
    }

    dev_tgt.dev_id = 0;
    dev_tgt.pipe_id = ALL_PIPES;

    auto &devMgr = bfrt::BfRtDevMgr::getInstance();
    bf_status = devMgr.bfRtInfoGet(dev_tgt.dev_id, program_name, &bfrtInfo);
    bf_sys_assert(bf_status == BF_SUCCESS);

    printf("[INFO] switchd initialization complete.\n");
}

/**
 * @brief Performs cleanup before exit.
 * 
 */
void teardown_switchd() {
    free(switchd_ctx);
}

#endif