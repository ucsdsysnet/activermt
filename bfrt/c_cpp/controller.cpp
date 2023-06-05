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

bool add_program_instance(
    std::shared_ptr<bfrt::BfRtSession> session, 
    std::unordered_map<int, instrset_action_t>* opcode_map,
    int fid, 
    int num_memaccess, 
    int* memaccess_idx, 
    int* current_allocation
) {
    std::set<int> apps;

    for(int i = 0; i < MAXINSTANCES; i++) {
        if(current_allocation[i] > 0)
            apps.insert(current_allocation[i]);
    }

    int occupancy = apps.size();

    if(occupancy == MAXINSTANCES) return false;

    int* num_blocks_allocated = (int*)calloc(occupancy + 1, sizeof(int));

    int num_filled = 0;
    while(num_filled < MAXINSTANCES) {
        for(int i = 0; i < occupancy + 1 && num_filled < MAXINSTANCES; i++, num_filled++) {
            num_blocks_allocated[i]++;
        }
    }

    memset(current_allocation, 0, MAXINSTANCES * sizeof(int));

    int offset = 0, i = 0;
    for(auto& it: apps) {
        for(int k = 0; k < num_blocks_allocated[i]; k++) {
            current_allocation[offset++] = it;
        }
        i++;
    }

    while(offset < MAXINSTANCES) {
        current_allocation[offset++] = fid;
    }

    std::unordered_map<int, active_malloc_blk_t> mem;

    int current_fid = current_allocation[0], mem_start = 0, mem_end = 0;
    for(int k = 1; k < MAXINSTANCES; k++) {
        if(current_fid != current_allocation[k]) {
            mem_end = k - 1;
            active_malloc_blk_t blk = {current_fid, -1, mem_start * GRANULARITY, (mem_end + 1) * GRANULARITY - 1};
            mem.insert({current_fid, blk});
            current_fid = current_allocation[k];
            mem_start = k;
        }
    }
    mem_end = MAXINSTANCES - 1;
    active_malloc_blk_t blk = {current_fid, -1, mem_start * GRANULARITY, (mem_end + 1) * GRANULARITY - 1};
    mem.insert({current_fid, blk});

    for(int k = 0; k < num_memaccess; k++) {
        update_instruction_entries(session, memaccess_idx[k] < NUM_STAGES_PIPE, memaccess_idx[k] % NUM_STAGES_PIPE, &mem, opcode_map);
    }

    return true;
}

void simulate_application_arrivals() {

    std::string basedir = getenv("ACTIVEP4_SRC");
    std::string instr_set_path = basedir + "/config/opcode_action_mapping.csv";

    std::unordered_map<std::string, instrset_action_t> instr_set;

    read_instruction_set(instr_set_path.c_str(), &instr_set);

    printf("Read instruction set with %lu instructions.\n", instr_set.size());

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns, elapsed_ms;
    int num_installed = 0;

    uint16_t fid = 1;
    int stage_id = 0;
    bool is_ingress = true;

    std::regex re_vaddr("ADDR_");
    std::regex re_mem("MEM_");

    std::shared_ptr<bfrt::BfRtSession> session = bfrt::BfRtSession::sessionCreate();

    /* Step 1 - initial installation. */

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }

    session->beginBatch();

    num_installed = 0;

    for(int i = 0; i < NUM_STAGES_PIPE * 2; i++) {
        stage_id = i % NUM_STAGES_PIPE;
        is_ingress = i < NUM_STAGES_PIPE;
        for(auto& it: instr_set) {
            if(std::regex_search(it.first, re_vaddr) || std::regex_search(it.first, re_mem)) continue;
            // std::cout << "Adding entry: " << it.first << " - (" << it.second.opcode << ", " << action << ", " << it.second.conditional << ")" << std::endl;
            install_instruction(
                session,
                is_ingress,
                stage_id,
                0,
                0,
                MAXMEM,
                &it.second
            );
            num_installed++;
        }
    }

    session->sessionCompleteOperations();
    session->endBatch(true);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    elapsed_ms = elapsed_ns / 1E6;

    printf("Init: %d entries installed in %lu ms.\n", num_installed, elapsed_ms);

    /* Step 2 - application arrivals. */

    int memaccess_idx[] = {0, 3, 7};
    int num_memaccess = 3;

    std::unordered_map<int, instrset_action_t> opcode_map;
    for(auto& it: instr_set) {
        opcode_map.insert({it.second.opcode, it.second});
    }

    int current_allocation[MAXINSTANCES];

    int num_repeats = 100;
    int num_apps = 20;

    init_analysis(num_repeats, num_apps);

    for(int r = 0; r < num_repeats; r++) {
        printf("[Experiment %d] ... \n", r + 1);
        for(int i = 0; i < MAXINSTANCES; i++)
            current_allocation[i] = 0;
        for(int k = 0; k < num_memaccess; k++) {
            clear_applications(session, memaccess_idx[k] < NUM_STAGES_PIPE, memaccess_idx[k] % NUM_STAGES_PIPE, &opcode_map);
        }
        bool success = false;
        for(int i = 0; i < num_apps; i++) {
            if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }
            success = add_program_instance(
                session,
                &opcode_map,
                i + 1,
                num_memaccess,
                memaccess_idx,
                current_allocation
            );
            if(!success) break;
            if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
            elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
            add_sample(-1, elapsed_ns);
            // int elapsed_ms = elapsed_ns / 1E6;
            // printf("Arrival: app %d installed in %d ms.\n", i + 1, elapsed_ms);
        }
        advance_experiment();
    }

    save_results("arrivals_");
}

void benchmark_table_update() {

    std::string basedir = getenv("ACTIVEP4_SRC");
    std::string instr_set_path = basedir + "/config/opcode_action_mapping.csv";

    std::unordered_map<std::string, instrset_action_t> instr_set;

    read_instruction_set(instr_set_path.c_str(), &instr_set);

    printf("Read instruction set with %lu instructions.\n", instr_set.size());

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;
    int num_installed = 0;

    uint16_t fid = 1;
    int stage_id = 0;
    bool is_ingress = true;

    std::regex re_vaddr("ADDR_");
    std::regex re_mem("MEM_");

    std::shared_ptr<bfrt::BfRtSession> session = bfrt::BfRtSession::sessionCreate();

    /* Step 1 - initial installation. */

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }

    session->beginBatch();

    num_installed = 0;

    for(auto& it: instr_set) {
        if(std::regex_search(it.first, re_vaddr) || std::regex_search(it.first, re_mem)) continue;
        // std::cout << "Adding entry: " << it.first << " - (" << it.second.opcode << ", " << action << ", " << it.second.conditional << ")" << std::endl;
        install_instruction(
            session,
            is_ingress,
            stage_id,
            0,
            0,
            65535,
            &it.second
        );
        num_installed++;
    }

    session->sessionCompleteOperations();
    session->endBatch(true);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("Init: %d entries installed in %lu ns.\n", num_installed, elapsed_ns);

    /* Step 2 - FID installation. */

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }

    session->beginBatch();

    num_installed = 0;

    for(auto& it: instr_set) {
        if(!std::regex_search(it.first, re_mem)) continue;
        // std::cout << "Adding entry: " << it.first << " - (" << it.second.opcode << ", " << action << ", " << it.second.conditional << ")" << std::endl;
        install_instruction(
            session,
            is_ingress,
            stage_id,
            fid,
            0,
            65535,
            &it.second
        );
        num_installed++;
    }

    add_quota_recirc_entry(session, fid);

    for(int i = 0; i < NUM_STAGES_PIPE; i++) {
        if(i != stage_id)
            add_allocation_entry(session, i, true, fid, 1, 0, 0, 0, 0);
        else
            add_allocation_entry(session, i, false, fid, 1, 0, 65535, 0, 0);
    }

    session->sessionCompleteOperations();
    session->endBatch(true);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("FID %d: %d entries installed in %lu ns.\n", fid, num_installed, elapsed_ns);

    /* Step 3: updated installation. */

    std::unordered_map<int, active_malloc_blk_t> mem;
    std::unordered_map<int, instrset_action_t> opcode_map;

    for(auto& it: instr_set) {
        opcode_map.insert({it.second.opcode, it.second});
    }

    active_malloc_blk_t blk = {fid, stage_id, 0, 32767};

    mem.insert({fid, blk});

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) { perror("clock_gettime"); exit(1); }

    update_instruction_entries(session, is_ingress, stage_id, &mem, &opcode_map);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("Entries updated in %lu ns.\n", elapsed_ns);
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

    // benchmark_heap_sync();
    // benchmark_table_update();
    simulate_application_arrivals();

    /* Run until exit. */

    while(is_running) sleep(1);
    
    printf("[INFO] Cleaning up ... \n");

    teardown_switchd();

    return EXIT_SUCCESS;
}