#ifndef MONITOR_H
#define MONITOR_H

#include <rte_log.h>
#include <rte_timer.h>
#include <rte_malloc.h>

#include "../../../../ref/uthash/include/uthash.h"
#include "../../../../headers/activep4.h"
#include "common.h"

int 
memory_consume_monitor(memory_t* mem, void* context) { 

    cache_context_t* ctxt = (cache_context_t*)context;

    if(ctxt->timer_snapshot_trigger == 1) {
        // read thresholds, frequent items.
        if(ctxt->frequent_items) rte_free(ctxt->frequent_items);
        ctxt->frequent_items = rte_zmalloc(NULL, MAX_DATA * sizeof(cache_item_t), 0);
        int num_thresholds = 0, stage_id = ctxt->monitor_stgid_threshold, num_matched = 0;
        for(int i = mem->sync_data[stage_id].mem_start; i < mem->sync_data[stage_id].mem_end; i++) {
            uint32_t threshold = mem->sync_data[stage_id].data[i];
            if(threshold > 0) {
                num_thresholds++;
                // printf("Threshold %u\n", threshold);
                uint32_t key_0 = mem->sync_data[ctxt->monitor_stgid_key_0].data[i];
                uint32_t key_1 = mem->sync_data[ctxt->monitor_stgid_key_1].data[i];
                uint64_t key = (uint64_t)key_0 << 32 | key_1;
                assert(key > 0);
                ctxt->frequent_items[ctxt->num_frequent_items].key = key;
                ctxt->frequent_items[ctxt->num_frequent_items].freq = threshold;
                ctxt->num_frequent_items++;
                cache_item_t* item;
                HASH_FIND_INT(ctxt->requested_items, &key, item);
                if(item != NULL) num_matched++;
            }
        }
        int num_items = HASH_COUNT(ctxt->requested_items);
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] received %u/%d objects (M %d) [%d matches].\n", num_thresholds, num_items, stage_id, num_matched);
        ctxt->timer_snapshot_trigger = 0;
        ctxt->timer_deallocate_trigger = 1;
    }

    return 0; 
}

int 
memory_invalidate_monitor(memory_t* mem, void* context) { return 0; }

int 
memory_reset_monitor(memory_t* mem, void* context) {

    cache_context_t* ctxt = (cache_context_t*)context;

    int memidx = 0;
    for(int i = 0; i < NUM_STAGES; i++) {
        if(!mem->valid_stages[i]) continue;
        memidx++;
        if(memidx == 3) ctxt->monitor_stgid_threshold = i;
        else if(memidx == 4) ctxt->monitor_stgid_key_1 = i;
        else if(memidx == 5) ctxt->monitor_stgid_key_0 = i;
    }

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] stages: threshold=%d, key_0=%d, key_1=%d\n", ctxt->monitor_stgid_threshold, ctxt->monitor_stgid_key_0, ctxt->monitor_stgid_key_1);

    uint32_t mem_start = mem->sync_data[ctxt->monitor_stgid_threshold].mem_start;
    if(mem->sync_data[ctxt->monitor_stgid_key_0].mem_start > mem_start) mem_start = mem->sync_data[ctxt->monitor_stgid_key_0].mem_start;
    if(mem->sync_data[ctxt->monitor_stgid_key_1].mem_start > mem_start) mem_start = mem->sync_data[ctxt->monitor_stgid_key_1].mem_start;

    uint32_t mem_end = mem->sync_data[ctxt->monitor_stgid_threshold].mem_end;
    if(mem_end > mem->sync_data[ctxt->monitor_stgid_key_0].mem_end) mem_end = mem->sync_data[ctxt->monitor_stgid_key_0].mem_end;
    if(mem_end > mem->sync_data[ctxt->monitor_stgid_key_1].mem_end) mem_end = mem->sync_data[ctxt->monitor_stgid_key_1].mem_end;

    uint32_t memory_size = mem_end - mem_start + 1;

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] memory idx (%d,%d,%d) effective memory size: %d, region start: %d\n", ctxt->monitor_stgid_threshold, ctxt->monitor_stgid_key_0, ctxt->monitor_stgid_key_1, memory_size, mem_start);

    ctxt->memory_start = mem_start;
    ctxt->memory_size = memory_size;

    return 0; 
}

void 
timer_monitor(void* arg) {

    activep4_context_t* ctxt = (activep4_context_t*)arg;
	cache_context_t* cache_ctxt = (cache_context_t*)ctxt->app_context;

    if(cache_ctxt->timer_deallocate_trigger) {
        cache_ctxt->timer_deallocate_trigger = 0;
        cache_ctxt->timer_ctxswtch_trigger = 1;
        ctxt->status = ACTIVE_STATE_DEALLOCATING;
        ctxt->timer_interval_us = 1000;
        uint64_t now = (double)(rte_rdtsc_precise() - cache_ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] context switch init %lu ms.\n", now);
    } else if(cache_ctxt->timer_ctxswtch_trigger) {
        if(ctxt->status == ACTIVE_STATE_TRANSMITTING) {
            cache_ctxt->timer_ctxswtch_trigger = 0;
            uint64_t now = (double)(rte_rdtsc_precise() - cache_ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
            rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] switching to cache %lu ms ... \n", now);
            context_switch_cache(ctxt);
            rte_delay_ms(200); // time to drain packets on the switch (pessimistic).
            memset(&ctxt->allocation, 0, sizeof(memory_t));
            memset(&ctxt->membuf, 0, sizeof(memory_t));
            ctxt->allocation.fid = ctxt->fid;
            ctxt->status = ACTIVE_STATE_INITIALIZING;
            assert(ctxt->current_pid == PID_CACHEREAD);
        } 
    } else {
        // ctxt->allocation.syncmap[5] = 1;
        // ctxt->allocation.syncmap[10] = 1;
        ctxt->allocation.syncmap[cache_ctxt->monitor_stgid_threshold] = 1;
        ctxt->allocation.syncmap[cache_ctxt->monitor_stgid_key_0] = 1;
        ctxt->allocation.syncmap[cache_ctxt->monitor_stgid_key_1] = 1;
        cache_ctxt->timer_snapshot_trigger = 1;
        ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
    }
}

#endif