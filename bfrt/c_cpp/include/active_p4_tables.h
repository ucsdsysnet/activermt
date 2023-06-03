#ifndef ACTIVE_P4_TABLES_H
#define ACTIVE_P4_TABLES_H

#include <bf_rt/bf_rt_table_key.hpp>
#include <bf_rt/bf_rt_table_data.hpp>
#include <bf_rt/bf_rt_table.hpp>

#include "controller_common.h"

/* Control Tables. */

static inline void add_ipv4_host_entry(
    program_context_t* ctxt,
    uint8_t* ipv4_dst_addr,
    uint16_t port,
    uint8_t* mac_dst_addr
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.ipv4_host", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_dst_addr = 0, id_action_send = 0, id_action_drop = 0, id_data_port = 0, id_data_mac = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ipv4.dst_addr", &id_key_dst_addr);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.send", &id_action_send);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.drop", &id_action_drop);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("port", id_action_send, &id_data_port);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("mac", id_action_send, &id_data_mac);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action_send, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_dst_addr, ipv4_dst_addr, 4);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableData->setValue(id_data_port, static_cast<uint64_t>(port));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableData->setValue(id_data_mac, mac_dst_addr, 6);
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

static inline void add_quota_recirc_entry(
    program_context_t* ctxt,
    uint16_t fid
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.quota_recirc", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

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

static inline void add_allocation_entry(
    program_context_t* ctxt,
    uint16_t fid,
    int flag_reqalloc,
    int* allocation_id
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.allocation", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_fid = 0, id_key_flag_reqalloc = 0, id_action_allocated = 0, id_action_pending = 0, id_data_allocation_id = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ih.fid", &id_key_fid);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.ih.flag_reqalloc", &id_key_flag_reqalloc);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.allocated", &id_action_allocated);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.pending", &id_action_pending);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    bf_status = bfrtTableKey->setValue(id_key_fid, static_cast<uint64_t>(fid));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValue(id_key_flag_reqalloc, static_cast<uint64_t>(flag_reqalloc));
    bf_sys_assert(bf_status == BF_SUCCESS);

    if(allocation_id == NULL) {
        tbl->dataReset(id_action_allocated, bfrtTableData.get());
        bf_status = bfrtTableData->setValue(id_data_allocation_id, static_cast<uint64_t>(*allocation_id));
        bf_sys_assert(bf_status == BF_SUCCESS);
    } else {
        tbl->dataReset(id_action_pending, bfrtTableData.get());
    }

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

static inline void add_routeback_entry(
    program_context_t* ctxt,
    int flag_reqalloc
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.routeback", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_flag_reqalloc = 0, id_action_route_malloc = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ih.flag_reqalloc", &id_key_flag_reqalloc);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.route_malloc", &id_action_route_malloc);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action_route_malloc, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_flag_reqalloc, static_cast<uint64_t>(flag_reqalloc));
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

static inline void add_remap_check_entry(
    program_context_t* ctxt,
    uint16_t fid,
    int flag_initiated,
    int allocation_id
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Ingress.remap_check", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_fid = 0, id_key_flag_initiated = 0, id_action_remapped = 0, id_data_allocation_id = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ih.fid", &id_key_fid);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.ih.flag_initiated", &id_key_flag_initiated);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.remapped", &id_action_remapped);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("allocation_id", id_action_remapped, &id_data_allocation_id);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action_remapped, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_fid, static_cast<uint64_t>(fid));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValue(id_key_flag_initiated, static_cast<uint64_t>(flag_initiated));
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

static inline void add_mirror_ack_entry(
    program_context_t* ctxt,
    int remap,
    int ingress_port,
    int session_id
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Egress.mirror_ack", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_remap = 0, id_key_ingress_port = 0, id_action_ack = 0, id_data_sessid = 0;

    bf_status = tbl->keyFieldIdGet("hdr.meta.remap", &id_key_remap);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.meta.ingress_port", &id_key_ingress_port);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Egress.ack", &id_action_ack);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("sessid", id_action_ack, &id_data_sessid);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action_ack, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_remap, static_cast<uint64_t>(remap));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableKey->setValue(id_key_ingress_port, static_cast<uint64_t>(ingress_port));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableData->setValue(id_data_sessid, static_cast<uint64_t>(session_id));
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

static inline void add_mirror_cfg_entry(
    program_context_t* ctxt,
    int egress_port,
    int session_id
) {
    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet("Egress.mirror_cfg", &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_egress_port = 0, id_action_set_mirror = 0, id_data_sessid = 0;

    bf_status = tbl->keyFieldIdGet("meta.egress_port", &id_key_egress_port);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Egress.set_mirror", &id_action_set_mirror);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataFieldIdGet("sessid", id_action_set_mirror, &id_data_sessid);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_status = tbl->keyAllocate(&bfrtTableKey);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->dataAllocate(&bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);

    tbl->keyReset(bfrtTableKey.get());
    tbl->dataReset(id_action_set_mirror, bfrtTableData.get());

    bf_status = bfrtTableKey->setValue(id_key_egress_port, static_cast<uint64_t>(egress_port));
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = bfrtTableData->setValue(id_data_sessid, static_cast<uint64_t>(session_id));
    bf_sys_assert(bf_status == BF_SUCCESS);

    uint64_t flags = 0;

    bf_status = tbl->tableEntryAdd(*session, dev_tgt, flags, *bfrtTableKey, *bfrtTableData);
    bf_sys_assert(bf_status == BF_SUCCESS);
}

/* Memory allocation tables. */

static inline void add_allocation_entry(
    program_context_t* ctxt,
    int stage_id,
    int is_default,
    uint16_t fid,
    int flag_allocated,
    int alloc_ig_start,
    int alloc_ig_end,
    int alloc_eg_start,
    int alloc_eg_end
) {
    char table_name[50];

    sprintf(table_name, "Ingress.allocation_%d", stage_id);

    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet(table_name, &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_fid = 0, id_key_flag_allocated = 0, id_action_get_allocation = 0, id_action_default_allocation = 0, id_data_offset_ig = 0, id_data_offset_eg = 0, id_data_size_ig = 0, id_data_size_eg = 0;

    bf_status = tbl->keyFieldIdGet("hdr.ih.fid", &id_key_fid);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->keyFieldIdGet("hdr.ih.flag_allocated", &id_key_flag_allocated);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.get_allocation", &id_action_get_allocation);
    bf_sys_assert(bf_status == BF_SUCCESS);
    bf_status = tbl->actionIdGet("Ingress.default_allocation", &id_action_default_allocation);
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

/* Active program execution tables. */

static inline void add_instruction_entry(
    std::shared_ptr<bfrt::BfRtSession> session,
    int ig_eg,
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
    char* action_name
) {
    char table_name[50];

    sprintf(table_name, "%s.instruction_%d", (ig_eg == 0) ? "Egress" : "Ingress", stage_id);

    const bfrt::BfRtTable* tbl = nullptr;
    auto bf_status = bfrtInfo->bfrtTableFromNameGet(table_name, &tbl);
    bf_sys_assert(bf_status == BF_SUCCESS);

    bf_rt_id_t id_key_fid = 0, id_key_opcode = 0, id_key_complete = 0, id_key_disabled = 0, id_key_mbr = 0, id_key_mar = 0, id_action = 0;

    char instr_id[50], action_id[50];
    sprintf(instr_id, "hdr.instr[%d].opcode", stage_id);
    sprintf(action_id, "%s.%s", (ig_eg == 0) ? "Egress" : "Ingress", action_name);

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

#endif