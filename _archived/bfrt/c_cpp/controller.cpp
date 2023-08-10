extern "C" {
// #include "common.h"
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
#include <bfutils/clish/thread.h>

#include <stdio.h>
#include <time.h>
#include <getopt.h>
#include <unistd.h>
#include <signal.h>
#include <arpa/inet.h>

#include <unordered_map>
#include <iostream>
#include <regex>
#include <set>

#include "include/utils.h"
#include "include/common.h"
#include "include/tables.h"
#include "include/telemetry.h"

void completion_cb(const bf_rt_target_t &dev_tgt, void *cookie) {}

static void interrupt_handler(int sig) {
    is_running = 0;
    printf("Exiting ... \n");
    // exit(1);
}

int main(int argc, char** argv) {

    signal(SIGINT, interrupt_handler);

    is_running = 1;

    // init_logger(boost::log::trivial::debug);
    init_switchd();

    /* Run until exit. */

    while(is_running) sleep(1);
    
    printf("[INFO] Cleaning up ... \n");

    teardown_switchd();

    return EXIT_SUCCESS;
}