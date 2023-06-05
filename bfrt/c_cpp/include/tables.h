#ifndef TABLES_H
#define TABLES_H

#include <string>

#include "common.h"

/**
 * @brief Add an allocation table entry.
 * 
 * @param session Session object
 * @param stage_id Active stage index for respective pipeline
 * @param is_default Is default allocation = 0
 * @param fid FID
 * @param flag_allocated Is allocated
 * @param alloc_ig_start Starting memory region of ingress
 * @param alloc_ig_end Ending memory region of ingress
 * @param alloc_eg_start Starting memory region of egress
 * @param alloc_eg_end Ending memory region of egress
 */
static inline void add_allocation_entry(
    std::shared_ptr<bfrt::BfRtSession> session,
    int stage_id,
    bool is_default,
    uint16_t fid,
    int flag_allocated,
    int alloc_ig_start,
    int alloc_ig_end,
    int alloc_eg_start,
    int alloc_eg_end
) {
    char table_name[50], action_name[50], action_name_default[50];
    sprintf(table_name, "Ingress.allocation_%d", stage_id);
    sprintf(action_name, "Ingress.get_allocation_s%d", stage_id);
    sprintf(action_name_default, "Ingress.default_allocation_s%d", stage_id);

    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet(table_name, &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    std::unique_ptr<bfrt::BfRtTableKey> bfrtTableKey;
    std::unique_ptr<bfrt::BfRtTableData> bfrtTableData;

    bf_rt_id_t id_key_fid = 0, id_key_flag_allocated = 0, id_action_get_allocation = 0, id_action_default_allocation = 0, id_data_offset_ig = 0, id_data_offset_eg = 0, id_data_size_ig = 0, id_data_size_eg = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ih.fid", &id_key_fid);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.ih.flag_allocated", &id_key_flag_allocated);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet(action_name, &id_action_get_allocation);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet(action_name_default, &id_action_default_allocation);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("offset_ig", id_action_get_allocation, &id_data_offset_ig);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("offset_eg", id_action_get_allocation, &id_data_offset_eg);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("size_ig", id_action_get_allocation, &id_data_size_ig);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("size_eg", id_action_get_allocation, &id_data_size_eg);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());

    bf_status = bfrtTableKey->setValue(id_key_fid, static_cast<uint64_t>(fid));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValue(id_key_flag_allocated, static_cast<uint64_t>(flag_allocated));
    bf_sys_assert(bf_status == BF_SUCCESS);

    if(is_default) {
        tbl->dataReset(id_action_default_allocation, bfrtTableData.get());
    } else {
        tbl->dataReset(id_action_get_allocation, bfrtTableData.get());
        bf_status = bfrtTableData->setValue(id_data_offset_ig, static_cast<uint64_t>(alloc_ig_start));
        bf_sys_assert(bf_status == BF_SUCCESS);
        bf_status = bfrtTableData->setValue(id_data_offset_eg, static_cast<uint64_t>(alloc_eg_start));
        bf_sys_assert(bf_status == BF_SUCCESS);
        bf_status = bfrtTableData->setValue(id_data_size_ig, static_cast<uint64_t>(alloc_ig_end));
        bf_sys_assert(bf_status == BF_SUCCESS);
        bf_status = bfrtTableData->setValue(id_data_size_eg, static_cast<uint64_t>(alloc_eg_end));
        bf_sys_assert(bf_status == BF_SUCCESS);
    }

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

/**
 * @brief Add bandwidth/recirculation quotas.
 * 
 * @param session Session object
 * @param fid FID
 */
static inline void add_quota_recirc_entry(
    std::shared_ptr<bfrt::BfRtSession> session,
    uint16_t fid
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.quota_recirc", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    std::unique_ptr<bfrt::BfRtTableKey> bfrtTableKey;
    std::unique_ptr<bfrt::BfRtTableData> bfrtTableData;

    bf_rt_id_t id_key_fid = 0, id_action_enable_recirculation = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ih.fid", &id_key_fid);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.enable_recirculation", &id_action_enable_recirculation);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action_enable_recirculation, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_fid, static_cast<uint64_t>(fid));
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

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
static inline bool add_instruction_entry(
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
    bf_sys_assert(bf_status == BF_SUCCESS || bf_status == BF_NO_SPACE);
    
    if(bf_status == BF_NO_SPACE) {
        printf("Ran out of space!\n");
        assert(1 == 0);
        return false;
    }
    
    return true;
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
static inline bool install_instruction(
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

    return true;
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
static inline bool update_instruction_entries(
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

    uint32_t usage_count = 0;
    bf_sys_assert(tbl->tableUsageGet(*session, dev_tgt, 0, &usage_count) == BF_SUCCESS);

    session->beginBatch();

    if(usage_count > 0) {
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

    return true;
}

static inline bool clear_applications(
    std::shared_ptr<bfrt::BfRtSession> session,
    bool is_ingress,
    int stage_id,
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

    uint32_t usage_count = 0;
    bf_sys_assert(tbl->tableUsageGet(*session, dev_tgt, 0, &usage_count) == BF_SUCCESS);

    session->beginBatch();

    if(usage_count > 0) {
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
            if(instr->second.memop) {
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
    }

    session->sessionCompleteOperations();
    session->endBatch(true);

    return true;
}

#endif