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

#define MAX_KEYLEN      64
#define MAX_MATCHKEYS   16
#define MAX_ACTIONDATA  8

#define ALL_PIPES       0xFFFF

const std::string program_name = "active";
const bfrt::BfRtInfo* bfrtInfo = nullptr;
static bf_switchd_context_t *switchd_ctx = NULL;
static int is_running = 0;
static bf_rt_target_t dev_tgt;

#include "include/controller_common.h"
// #include "include/active_p4_tables.h"

static inline void add_instruction_entry(
    std::shared_ptr<bfrt::BfRtSession> session,
    int is_egress,
    int stage_id,
    uint16_t fid_start,
    uint16_t fid_end,
    int opcode,
    int complete,
    int disabled,
    int mbr,
    int mbr_mask,
    int mar_start,
    int mar_end,
    const char* action_name
) {
    char table_name[50];

    sprintf(table_name, "%s.instruction_%d", (is_egress == 0) ? "Egress" : "Ingress", stage_id);

    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet(table_name, &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    std::unique_ptr<bfrt::BfRtTableKey> bfrtTableKey;
    std::unique_ptr<bfrt::BfRtTableData> bfrtTableData;

    bf_rt_id_t id_key_fid = 0, id_key_opcode = 0, id_key_complete = 0, id_key_disabled = 0, id_key_mbr = 0, id_key_mar = 0, id_action = 0;

    char instr_id[50], action_id[50];
    sprintf(instr_id, "hdr.instr$%d.opcode", stage_id);
    sprintf(action_id, "%s.%s", (is_egress == 0) ? "Egress" : "Ingress", action_name);

    bf_status = tbl->keyFieldIdGet("hdr.meta.fid", &id_key_fid);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet(instr_id, &id_key_opcode);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.meta.complete", &id_key_complete);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.meta.disabled", &id_key_disabled);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.meta.mbr", &id_key_mbr);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.meta.mar[19:0]", &id_key_mar);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet(action_id, &id_action);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_opcode, static_cast<uint64_t>(opcode));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValue(id_key_complete, static_cast<uint64_t>(complete));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValue(id_key_disabled, static_cast<uint64_t>(disabled));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValueRange(id_key_fid, static_cast<uint64_t>(fid_start), static_cast<uint64_t>(fid_end));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValueRange(id_key_mar, static_cast<uint64_t>(mar_start), static_cast<uint64_t>(mar_end));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValueLpm(id_key_mbr, static_cast<uint64_t>(mbr), static_cast<uint16_t>(mbr_mask));
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

void completion_cb(const bf_rt_target_t &dev_tgt, void *cookie) {}

void benchmark_table_update() {

    std::string basedir = getenv("ACTIVEP4_SRC");
    std::string instr_set_path = basedir + "/config/opcode_action_mapping.csv";

    std::unordered_map<std::string, instrset_action_t> instr_set;

    read_instruction_set(instr_set_path.c_str(), &instr_set);

    printf("Read instruction set with %lu instructions.\n", instr_set.size());

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }

    std::shared_ptr<bfrt::BfRtSession> session = bfrt::BfRtSession::sessionCreate();

    session->beginBatch();

    uint16_t fid = 1;
    int stage_id = 0;

    std::regex re_idx("#");
    std::regex re_vaddr("ADDR_");

    int num_installed = 0;

    for(auto& it: instr_set) {
        if(std::regex_search(it.first, re_vaddr)) continue;
        std::string action = std::regex_replace(it.second.action, re_idx, std::to_string(stage_id));
        // std::cout << "Adding entry: " << it.first << " - (" << it.second.opcode << ", " << action << ", " << it.second.conditional << ")" << std::endl;
        add_instruction_entry(
            session,
            1,
            stage_id,
            fid,
            fid,
            it.second.opcode,
            0,
            0,
            0,
            (it.second.conditional) ? 0 : 32,
            0,
            65535,
            action.c_str()
        );
        num_installed++;
    }

    session->sessionCompleteOperations();
    session->endBatch(true);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("%d entries installed in %lu ns.\n", num_installed, elapsed_ns);
}

void benchmark_heap_sync() {

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    std::shared_ptr<bfrt::BfRtSession> session = bfrt::BfRtSession::sessionCreate();

    const bfrt::BfRtTable* heap_s0 = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.heap_s0", &heap_s0);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bfrt::BfRtTable::TableType tblType;
    bf_status = heap_s0->tableTypeGet(&tblType);
    bf_sys_assert(bf_status == BF_SUCCESS);

    size_t entry_count = 0;
    bf_status = heap_s0->tableSizeGet(*session, dev_tgt, 0, &entry_count);
    bf_sys_assert(bf_status == BF_SUCCESS);

    printf("Heap 0 table type is %d with %ld entries.\n", (int)tblType, entry_count);

    bfrt::BfRtTable::keyDataPairs key_data_pairs;
    std::vector<std::unique_ptr<bfrt::BfRtTableKey>> keys(entry_count);
    std::vector<std::unique_ptr<bfrt::BfRtTableData>> data(entry_count);

    for(int i = 0; i < entry_count; ++i) {
        bf_status = heap_s0->keyAllocate(&keys[i]);
        bf_sys_assert(bf_status == BF_SUCCESS);
        bf_status = heap_s0->dataAllocate(&data[i]);
        bf_sys_assert(bf_status == BF_SUCCESS);
        key_data_pairs.push_back(std::make_pair(keys[i].get(), data[i].get()));
    }

    std::unique_ptr<bfrt::BfRtTableOperations> idcTableOps;
    bf_status = heap_s0->operationsAllocate(bfrt::TableOperationsType::REGISTER_SYNC, &idcTableOps);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = idcTableOps->registerSyncSet(*session, dev_tgt, completion_cb, NULL);
    bf_sys_assert(bf_status == BF_SUCCESS);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }

    bf_status = heap_s0->tableOperationsExecute(*idcTableOps);
    bf_sys_assert(bf_status == BF_SUCCESS);

    session->beginBatch();

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
    bf_sys_assert(bf_status == BF_SUCCESS);

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
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_field_heap_value = 0;
    bf_sys_assert(heap_s0->dataFieldIdGet("Ingress.heap_s0.f1", &id_field_heap_value) == BF_SUCCESS);

    session->sessionCompleteOperations();
    session->endBatch(true);

    // for(int i = 0; i < num_returned; i++) {
    //     uint64_t value;
    //     bf_sys_assert(key_data_pairs[i].second->getValue(id_field_heap_value, &value) == BF_SUCCESS);
    //     printf("Value of object = %lu\n", value);
    //     break;
    // }

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("Register sync time for %d entries %ld ns.\n", num_returned, elapsed_ns);
}

void experiment() {

    // std::string basedir = "../..";
    // std::string config = "ptf";

    std::shared_ptr<bfrt::BfRtSession>  session = bfrt::BfRtSession::sessionCreate();

    // program_context_t ctxt;
    // ctxt.bfrtInfo = bfrtInfo;
    // ctxt.session = session;
    // ctxt.basedir = basedir;

    // routing_config_t routecfg;
    
    // std::unordered_map<std::string, instrset_action_t> instruction_set;

    // read_routing_configuration(&ctxt, config, &routecfg);
    // read_instruction_set(&ctxt, &instruction_set);

    /* Setup tables. */

    // session->beginBatch();

    // add_routeback_entry(&ctxt, 1);
    // add_routeback_entry(&ctxt, 2);

    // for(std::pair<std::string, int> element : routecfg.ip_config) {
    //     auto ip_addr = element.first;
    //     auto port = element.second;
    //     in_addr ip_addr_bytes;
    //     inet_aton(ip_addr.c_str(), &ip_addr_bytes);
    //     //add_ipv4_host_entry(&ctxt, (uint8_t*)ip_addr_bytes.s_addr, port, routecfg.mac_config.at(port));
    // }

    // session->sessionCompleteOperations();
    // session->endBatch(true);

    printf("Operation(s) complete.\n");
}

static void interrupt_handler(int sig) {
    is_running = 0;
    printf("Exiting ... \n");
    // exit(1);
}

int main(int argc, char** argv) {

    signal(SIGINT, interrupt_handler);

    is_running = 1;

    std::string install_dir = getenv("SDE_INSTALL");
    std::string config_file = install_dir + "/share/p4/targets/tofino/" + program_name + ".conf";

    printf("Using SDE path: %s\n", install_dir.c_str());
    printf("Using config: %s\n", config_file.c_str());

    /* Initialization. */

    switchd_ctx = (bf_switchd_context_t *)calloc(1, sizeof(bf_switchd_context_t));
    if(!switchd_ctx) {
        printf("Unable to allocate switchd context.\n");
        exit(1);
    }

    switchd_ctx->init_mode = BF_DEV_WARM_INIT_FAST_RECFG;
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

    // benchmark_heap_sync();
    benchmark_table_update();

    /* Run until exit. */

    while(is_running) sleep(1);
    
    printf("[INFO] Cleaning up ... \n");

    free(switchd_ctx);

    return EXIT_SUCCESS;
}