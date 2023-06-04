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
#define MAXMEM          94207
#define OPEOF           0

#define ALL_PIPES       0xFFFF

const std::string program_name = "active";
const bfrt::BfRtInfo* bfrtInfo = nullptr;
static bf_switchd_context_t *switchd_ctx = NULL;
static int is_running = 0;
static bf_rt_target_t dev_tgt;

#include "include/controller_common.h"
// #include "include/active_p4_tables.h"

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
 * @brief Adds an instruction table entry.
 * 
 * @param session Session object
 * @param is_ingress Ingress/Egress pipeline
 * @param stage_id Active stage index for respective pipeline
 * @param fid_start Staring FID
 * @param fid_end Ending FID
 * @param opcode Instruction opcode
 * @param complete Execution is complete flag
 * @param disabled Execution was disabled by branching flag
 * @param mbr Conditional spec = 0
 * @param mbr_mask Conditional spec: should be 0 if true else 32
 * @param mar_start Memory region start
 * @param mar_end Memory region end
 * @param action_name Name of P4 action to invoke
 */
static inline void add_instruction_entry(
    std::shared_ptr<bfrt::BfRtSession> session,
    bool is_ingress,
    int stage_id,
    int fid_start, 
    int fid_end,
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
    sprintf(table_name, "%s.instruction_%d", !is_ingress ? "Egress" : "Ingress", stage_id);

    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet(table_name, &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    std::unique_ptr<bfrt::BfRtTableKey> bfrtTableKey;
    std::unique_ptr<bfrt::BfRtTableData> bfrtTableData;

    bf_rt_id_t id_key_fid = 0, id_key_opcode = 0, id_key_complete = 0, id_key_disabled = 0, id_key_mbr = 0, id_key_mar = 0, id_action = 0;

    char instr_id[50], action_id[50];
    sprintf(instr_id, "hdr.instr$%d.opcode", stage_id);
    sprintf(action_id, "%s.%s", !is_ingress ? "Egress" : "Ingress", action_name);

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

/**
 * @brief Installs an instruction.
 * 
 * @param session Session object
 * @param is_ingress is_ingress Ingress/Egress pipeline
 * @param stage_id stage_id Active stage index for respective pipeline
 * @param fid FID of function
 * @param mar_start Memory region start
 * @param mar_end Memory region end
 * @param instr Instruction definition
 */
static inline void install_instruction(
    std::shared_ptr<bfrt::BfRtSession> session,
    bool is_ingress,
    int stage_id,
    int fid,
    int mar_start,
    int mar_end,
    instrset_action_t* instr
) {
    assert(mar_start >= 0);
    assert(mar_end <= MAXMEM);

    const int complete = 0;
    int disabled = 0;
    uint16_t fid_start = instr->memop ? fid : 0, fid_end = instr->memop ? fid : 0xFF;
    int mbr = 0, mbr_mask = instr->conditional ? 0 : 32;
    int opcode = instr->opcode;

    std::regex re_idx("#");

    std::string action = instr->action;
    action = std::regex_replace(action, re_idx, std::to_string(stage_id));

    std::string action_rejoin = "attempt_rejoin_s#";
    action_rejoin = std::regex_replace(action_rejoin, re_idx, std::to_string(stage_id));
    
    std::string action_skip = "skip";

    if(instr->conditional) {
        if(instr->condition) {
            add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 0, 0, mbr, 0, mar_start, mar_end, action.c_str());
            add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 0, 0, mbr, 32, mar_start, MAXMEM, action_skip.c_str());
        } else {
            add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 0, 0, mbr, 32, mar_start, mar_end, action.c_str());
            add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 0, 0, mbr, 0, mar_start, MAXMEM, action_skip.c_str());
        }
    } else {
        if(opcode == OPEOF) {
            add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 1, 0, mbr, 0, mar_start, mar_end, action.c_str());
        }
        add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 0, 0, mbr, 0, mar_start, mar_end, action.c_str());
    }
    add_instruction_entry(session, is_ingress, stage_id, fid_start, fid_end, opcode, 0, 1, mbr, 0, mar_start, MAXMEM, action_rejoin.c_str());
}

/**
 * @brief Updates an installed instruction corresponding to a memory reallocation.
 * 
 * @param session Session object
 * @param is_ingress is_ingress is_ingress Ingress/Egress pipeline
 * @param stage_id stage_id stage_id Active stage index for respective pipeline
 * @param mem memory allocation for each FID belonging the stage
 * @param opcode_map mapping from opcode to the instruction definition
 */
static inline void update_instruction_entries(
    std::shared_ptr<bfrt::BfRtSession> session,
    bool is_ingress,
    int stage_id,
    std::unordered_map<int, active_malloc_blk_t>* mem,
    std::unordered_map<int, instrset_action_t>* opcode_map
) {
    char table_name[50];
    sprintf(table_name, "%s.instruction_%d", (is_ingress == 0) ? "Egress" : "Ingress", stage_id);

    const bfrt::BfRtTable* tbl;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet(table_name, &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    size_t entry_count = 0;
    bf_sys_assert(tbl->tableSizeGet(*session, dev_tgt, 0, &entry_count) == BF_SUCCESS);

    bfrt::BfRtTable::keyDataPairs key_data_pairs;
    std::vector<std::unique_ptr<bfrt::BfRtTableKey>> keys(entry_count);
    std::vector<std::unique_ptr<bfrt::BfRtTableData>> data(entry_count);

    for(int i = 0; i < entry_count; ++i) {
        bf_sys_assert(tbl->keyAllocate(&keys[i]) == BF_SUCCESS);
        bf_sys_assert(tbl->dataAllocate(&data[i]) == BF_SUCCESS);
        key_data_pairs.push_back(std::make_pair(keys[i].get(), data[i].get()));
    }

    bf_rt_id_t id_key_fid = 0, id_key_opcode = 0;

    char instr_id[50];
    sprintf(instr_id, "hdr.instr$%d.opcode", stage_id);
    bf_sys_assert(tbl->keyFieldIdGet("hdr.meta.fid", &id_key_fid) == BF_SUCCESS);
    bf_sys_assert(tbl->keyFieldIdGet(instr_id, &id_key_opcode) == BF_SUCCESS);

    session->beginBatch();

    std::unique_ptr<bfrt::BfRtTableKey> gIdcKey;
    std::unique_ptr<bfrt::BfRtTableData> gIdcData;
    bf_status = tbl->keyAllocate(&gIdcKey);
    bf_status = tbl->dataAllocate(&gIdcData);

    uint64_t fid_start, fid_end, opcode;

    bf_status = tbl->keyReset(gIdcKey.get());
    bf_status = tbl->dataReset(gIdcData.get());
    bf_status = tbl->tableEntryGetFirst(
        *session, 
        dev_tgt, 
        bfrt::BfRtTable::BfRtTableGetFlag::GET_FROM_SW, 
        gIdcKey.get(), 
        gIdcData.get()
    );
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_sys_assert(gIdcKey.get()->getValueRange(id_key_fid, &fid_start, &fid_end) == BF_SUCCESS);
    bf_sys_assert(gIdcKey.get()->getValue(id_key_opcode, &opcode) == BF_SUCCESS);

    uint32_t num_returned = 0;
    bf_status = tbl->tableEntryGetNext_n(
        *session,
        dev_tgt,
        *gIdcKey.get(),
        entry_count,
        bfrt::BfRtTable::BfRtTableGetFlag::GET_FROM_SW,
        &key_data_pairs,
        &num_returned
    );
    bf_sys_assert(bf_status == BF_SUCCESS);

    for(auto& it: key_data_pairs) {
        bf_sys_assert(it.first->getValueRange(id_key_fid, &fid_start, &fid_end) == BF_SUCCESS);
        bf_sys_assert(it.first->getValue(id_key_opcode, &opcode) == BF_SUCCESS);
        if(fid_start == 0 && fid_end == 0) continue;
        auto instr = opcode_map->find(opcode);
        assert(instr != opcode_map->end());
        if(instr->second.memop && mem->find(fid_start) != mem->end()) {
            // std::cout << "Deleting " << instr->first << " opcode " << opcode << " ... " << std::endl;
            bf_status = tbl->tableEntryDel(
                *session,
                dev_tgt,
                0,
                *it.first
            );
            bf_sys_assert(bf_status == BF_SUCCESS);
        }
        // std::cout << "Entry: (" << fid_start << "," << fid_end << ") - " << opcode << std::endl;
    }

    for(auto& it: *mem) {
        uint16_t fid = it.first;
        active_malloc_blk_t* blk = &it.second;
        for(auto& op: *opcode_map) {
            if(op.second.memop) {
                // std::cout << "adding instruction " << fid << " " << op.second.opcode << " - " << blk->mem_start << "," << blk->mem_end << std::endl;
                install_instruction(
                    session,
                    is_ingress,
                    stage_id,
                    fid,
                    blk->mem_start,
                    blk->mem_end,
                    &op.second
                );
            }
        }
    }

    session->sessionCompleteOperations();
    session->endBatch(true);
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

    benchmark_heap_sync();
    benchmark_table_update();

    /* Run until exit. */

    while(is_running) sleep(1);
    
    printf("[INFO] Cleaning up ... \n");

    free(switchd_ctx);

    return EXIT_SUCCESS;
}