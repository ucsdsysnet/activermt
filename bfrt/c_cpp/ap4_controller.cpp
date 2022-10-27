extern "C" {
#include "common.h"
#include <bfsys/bf_sal/bf_sys_intf.h>
}

#include <bf_rt/bf_rt.hpp>
#include <bf_rt/bf_rt_info.hpp>
#include <bf_rt/bf_rt_init.hpp>
#include <bf_rt/bf_rt_common.h>
#include <bf_rt/bf_rt_table_key.hpp>
#include <bf_rt/bf_rt_table_data.hpp>
#include <bf_rt/bf_rt_table.hpp>
#include <bf_rt/bf_rt_table_operations.hpp>
#include <bf_switchd/bf_switchd.h>
#include <dvm/bf_drv_intf.h>
#include <bfutils/clish/thread.h>

#include <stdio.h>
#include <time.h>
#include <getopt.h>
#include <unistd.h>

#define ALL_PIPES 0xffff

static const char* p4_program_name      = "active";
bf_rt_target_t dev_tgt                  = {0, ALL_PIPES};

void completion_cb(const bf_rt_target_t &dev_tgt, void *cookie) {
    printf("Sync operation complete!\n");
}

int main(int argc, char** argv) {

    parse_opts_and_switchd_init(argc, argv);

    /*switchd_ctx.running_in_background = false;
    switchd_ctx.is_sw_model = false;
    switchd_ctx.is_asic = true;
    switchd_ctx.shell_set_ucli = false;
    bf_status_t status = bf_switchd_lib_init(&switchd_ctx);*/

    const bfrt::BfRtInfo *bfrtInfo = nullptr;
    std::shared_ptr<bfrt::BfRtSession> session;

    auto &devMgr = bfrt::BfRtDevMgr::getInstance();
    auto bf_status = devMgr.bfRtInfoGet(dev_tgt.dev_id, "active", &bfrtInfo);
    bf_sys_assert(bf_status == BF_SUCCESS);

    session = bfrt::BfRtSession::sessionCreate();

    const bfrt::BfRtTable* heap_s0 = nullptr;
    bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.heap_s0", &heap_s0);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bfrt::BfRtTable::TableType tblType;
    bf_status = heap_s0->tableTypeGet(&tblType);
    bf_sys_assert(bf_status == BF_SUCCESS);

    size_t entry_count = 0;
    bf_status = heap_s0->tableSizeGet(*session, dev_tgt, 0, &entry_count);
    assert(bf_status == BF_SUCCESS);

    printf("Heap 0 table type is %d with %ld entries.\n", (int)tblType, entry_count);

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    std::unique_ptr<bfrt::BfRtTableOperations> idcTableOps;
    bf_status = heap_s0->operationsAllocate(bfrt::TableOperationsType::REGISTER_SYNC, &idcTableOps);
    assert(bf_status == BF_SUCCESS);

    session->beginBatch();

    bf_status = idcTableOps->counterSyncSet(*session, dev_tgt, completion_cb, NULL);
    assert(bf_status == BF_SUCCESS);
    bf_status = heap_s0->tableOperationsExecute(*idcTableOps);
    assert(bf_status == BF_SUCCESS);

    bfrt::BfRtTable::keyDataPairs key_data_pairs;
    std::vector<std::unique_ptr<bfrt::BfRtTableKey>> keys(entry_count);
    std::vector<std::unique_ptr<bfrt::BfRtTableData>> data(entry_count);

    for(int i = 0; i < entry_count; ++i) {
        bf_status = heap_s0->keyAllocate(&keys[i]);
        assert(bf_status == BF_SUCCESS);
        bf_status = heap_s0->dataAllocate(&data[i]);
        assert(bf_status == BF_SUCCESS);
        key_data_pairs.push_back(std::make_pair(keys[i].get(), data[i].get()));
    }

    std::unique_ptr<bfrt::BfRtTableKey> gIdcKey;
    std::unique_ptr<bfrt::BfRtTableData> gIdcData;
    bf_status = heap_s0->keyAllocate(&gIdcKey);
    bf_status = heap_s0->dataAllocate(&gIdcData);

    bf_status = heap_s0->keyReset(gIdcKey.get());
    bf_status = heap_s0->dataReset(gIdcData.get());
    bf_status = heap_s0->tableEntryGetFirst(
        *session, 
        dev_tgt, 
        bfrt::BfRtTable::BfRtTableGetFlag::GET_FROM_SW, 
        gIdcKey.get(), 
        gIdcData.get()
    );
    assert(bf_status == BF_SUCCESS);

    uint32_t num_returned = 0;
    bf_status = heap_s0->tableEntryGetNext_n(
        *session,
        dev_tgt,
        *gIdcKey.get(),
        entry_count,
        bfrt::BfRtTable::BfRtTableGetFlag::GET_FROM_SW,
        &key_data_pairs,
        &num_returned
    );
    assert(bf_status == BF_SUCCESS);

    session->sessionCompleteOperations();
    session->endBatch(true);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("Register sync time for %d entries %ld ns.\n", num_returned, elapsed_ns);

    run_cli_or_cleanup();

    printf("Operation(s) complete.\n");

    return EXIT_SUCCESS;
}