/**
 * @file cache.h
 * @author Rajdeep Das (r4das@ucsd.edu)
 * @brief 
 * @version 1.0
 * @date 2023-08-18
 * 
 * @copyright Copyright (c) 2023 Rajdeep Das, University of California San Diego.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 */

#ifndef CACHE_H
#define CACHE_H

#include <rte_common.h>
#include <rte_hash_crc.h>
#include <rte_malloc.h>
#include <rte_timer.h>
#include <rte_memcpy.h>

#include "../../../../../ref/uthash/include/uthash.h"
#include "../../../../../include/c/common/activep4.h"

#include "common.h"

#define DEBUG_CACHE

int
compare_elements_cache(const void * a, const void * b) {
	return ( ((cache_item_t*)b)->freq - ((cache_item_t*)a)->freq );
}

void 
shutdown_cache(int id, void* context) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	if(cache_ctxt->num_samples == 0) return;
	char filename[50];
	sprintf(filename, "cache_rx_stats_%d.csv", id);
    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Writing %d samples written to %s ... \n", id, cache_ctxt->num_samples, filename);
	FILE* fp = fopen(filename, "w");
	for(int i = 0; i < cache_ctxt->num_samples; i++) {
		fprintf(fp, "%lu,%u,%u\n", cache_ctxt->rx_stats[i].ts, cache_ctxt->rx_stats[i].rx_hits, cache_ctxt->rx_stats[i].rx_total);
	}
	fclose(fp);

	#ifdef DEBUG_CACHE
	sprintf(filename, "debug_invalid_objects_%d.csv", id);
	fp = fopen(filename, "w");
	for(cache_debug_t* item = cache_ctxt->debug; item != NULL; item = item->hh.next) {
		fprintf(fp, "%lu,%u,%u,%u,%u\n", item->key, item->value, item->key_0, item->key_1, item->addr);
	}
	fclose(fp);
	#endif
}

int 
memory_consume_cache(memory_t* mem, void* context) { return 0; }

int 
memory_invalidate_cache(memory_t* mem, void* context) { 

	for(int i = 0; i < NUM_STAGES; i++) {
		memset(mem->sync_data[i].data, 0, sizeof(uint32_t) * MAX_DATA);
	}

	rte_memcpy(mem->syncmap, mem->valid_stages, NUM_STAGES);

	return 1; 
}

int 
memory_reset_cache(memory_t* mem, void* context) {

	cache_context_t* cache_ctxt = (cache_context_t*)context;

	if(cache_ctxt->timer_reset_trigger == 1) {

		cache_ctxt->timer_reset_trigger = 0;

		return 1;
	} else {

		for(int i = 0, k = 0; i < NUM_STAGES && k < 3; i++) {
			if(!mem->valid_stages[i]) continue;
			if(k == 0) cache_ctxt->stage_id_key_0 = i;
			else if(k == 1) cache_ctxt->stage_id_key_1 = i;
			else if(k == 2) cache_ctxt->stage_id_value = i;
			k++;
		}

		uint32_t mem_start = mem->sync_data[cache_ctxt->stage_id_key_0].mem_start;
		if(mem->sync_data[cache_ctxt->stage_id_key_1].mem_start > mem_start) mem_start = mem->sync_data[cache_ctxt->stage_id_key_1].mem_start;
		if(mem->sync_data[cache_ctxt->stage_id_value].mem_start > mem_start) mem_start = mem->sync_data[cache_ctxt->stage_id_value].mem_start;

		uint32_t mem_end = mem->sync_data[cache_ctxt->stage_id_key_0].mem_end;
		if(mem_end > mem->sync_data[cache_ctxt->stage_id_key_1].mem_end) mem_end = mem->sync_data[cache_ctxt->stage_id_key_1].mem_end;
		if(mem_end > mem->sync_data[cache_ctxt->stage_id_value].mem_end) mem_end = mem->sync_data[cache_ctxt->stage_id_value].mem_end;

		uint32_t memory_size = mem_end - mem_start + 1;

		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[CACHE] memory idx (%d,%d,%d) effective memory size: %d, region start: %d\n", cache_ctxt->stage_id_key_0, cache_ctxt->stage_id_key_1, cache_ctxt->stage_id_value, memory_size, mem_start);

		cache_ctxt->memory_start = mem_start;
		cache_ctxt->memory_size = memory_size;

		return 0;
	}
}

void 
timer_cache(void* arg) {
	
	activep4_context_t* ctxt = (activep4_context_t*)arg;
	cache_context_t* cache_ctxt = (cache_context_t*)ctxt->app_context;

	if(ctxt->timer_interval_us < HH_ITVL_MAX_MS * 1E3) {
		ctxt->timer_interval_us *= 2;
		ctxt->timer_interval_us = (ctxt->timer_interval_us > HH_ITVL_MAX_MS * 1E3) ? HH_ITVL_MAX_MS * 1E3 : ctxt->timer_interval_us;
	}

	HASH_SORT(cache_ctxt->requested_items, compare_elements_cache);

	memset(&ctxt->membuf, 0, sizeof(ctxt->membuf));

	uint32_t num_stored = 0, num_total = 0, max_freq = 0, estimated_hitrate = 0, sum_freq = 0;

	uint8_t bloom[MAX_CACHE_SIZE];
	memset(bloom, 0, MAX_CACHE_SIZE);

	if(!cache_ctxt->frequent_item_monitor) {
		cache_item_t* item;
		for(item = cache_ctxt->requested_items; item != NULL && num_stored < cache_ctxt->memory_size; item = item->hh.next) {
			// estimated_hitrate += item->freq;
			max_freq = (item->freq > max_freq) ? item->freq : max_freq;
			// uint32_t paddr = cache_ctxt->memory_start + item->vaddr % cache_ctxt->memory_size;
			uint64_t key = item->key;
			uint32_t key_0 = key >> 32;
			uint32_t key_1 = key & 0xFFFFFFFF;
			assert(key_0 > 0 || key_1 > 0);
			uint32_t vaddr = rte_hash_crc_8byte(key, 0);
			uint32_t paddr = cache_ctxt->memory_start + vaddr % cache_ctxt->memory_size;
			if(bloom[paddr]) continue;
			ctxt->membuf.sync_data[cache_ctxt->stage_id_key_0].data[paddr] = key_0;
			ctxt->membuf.sync_data[cache_ctxt->stage_id_key_1].data[paddr] = key_1;
			ctxt->membuf.sync_data[cache_ctxt->stage_id_value].data[paddr] = 1;
			num_stored++;
			bloom[paddr] = 1;
			estimated_hitrate += item->freq;
			// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "storing item %lu freq %d\n", key, item->freq);
		}

		if(num_stored > 0) {
			for(item = cache_ctxt->requested_items; item != NULL; item = item->hh.next) {
				sum_freq += item->freq;
				num_total++;
			}
			#ifdef DEBUG_CACHE
			rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "estimated hit rate: %f\n", estimated_hitrate * 1.0f / sum_freq);
			#endif
		}
	} else {
		for(int i = 0; i < cache_ctxt->num_frequent_items; i++) {
			cache_item_t* item = &cache_ctxt->frequent_items[i];
			uint64_t key = item->key;
			uint32_t key_0 = key >> 32;
			uint32_t key_1 = key & 0xFFFFFFFF;
			assert(key_0 > 0 || key_1 > 0);
			uint32_t vaddr = rte_hash_crc_8byte(key, 0);
			uint32_t paddr = cache_ctxt->memory_start + vaddr % cache_ctxt->memory_size;
			if(bloom[paddr]) continue;
			ctxt->membuf.sync_data[cache_ctxt->stage_id_key_0].data[paddr] = key_0;
			ctxt->membuf.sync_data[cache_ctxt->stage_id_key_1].data[paddr] = key_1;
			ctxt->membuf.sync_data[cache_ctxt->stage_id_value].data[paddr] = 1;
			num_stored++;
			bloom[paddr] = 1;
			estimated_hitrate += item->freq;
		}
		#ifdef DEBUG_CACHE
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "storing %d items from monitor.\n", num_stored);
		#endif
	}

	rte_memcpy(ctxt->allocation.syncmap, ctxt->allocation.valid_stages, NUM_STAGES);

	// HASH_CLEAR(hh, cache_ctxt->requested_items);

	if(num_stored > 0) {
		cache_ctxt->timer_reset_trigger = 1;
		ctxt->status = ACTIVE_STATE_UPDATING;
	}

	#ifdef DEBUG_CACHE
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Frequent items = %d, total items = %d, max frequency = %u\n", num_stored, num_total, max_freq);	
	#endif
}

void
on_allocation_cache(void* arg) {

	activep4_context_t* ctxt = (activep4_context_t*)arg;
	cache_context_t* cache_ctxt = (cache_context_t*)ctxt->app_context;

	ctxt->timer_interval_us = HH_ITVL_MIN_MS * 1E3;

	if(cache_ctxt->frequent_item_monitor) {
		uint64_t now = (double)(rte_rdtsc_precise() - cache_ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[CACHE] context switch complete after %lu ms.\n", now);
	}
}

void
read_key_dist(char* filename, uint64_t* keydist, int* n) {
    FILE* fp = fopen(filename, "r");
    assert(fp != NULL);
	char buf[1024];
	*n = 0;
	while( fgets(buf, 1024, fp) > 0 ) {
		uint64_t key = atol(buf);
        keydist[(*n)++] = key;
	}
	fclose(fp);
}

static __rte_always_inline void
tx_update_args(cache_context_t* ctxt, activep4_data_t* args) {

    if(ctxt->memory_size < 2) return;

    uint64_t key = ctxt->keydist[ctxt->current_key_idx];

    ctxt->current_key_idx = (ctxt->current_key_idx + 1) % ctxt->distsize;

    uint32_t key_0 = key >> 32;;
	uint32_t key_1 = key & 0xFFFFFFFF;

    uint32_t vaddr = rte_hash_crc_8byte(key, 0);
	uint32_t paddr = ctxt->memory_start + vaddr % ctxt->memory_size;

    args->data[0] = htonl(paddr);
    args->data[1] = htonl(key_0);
    args->data[2] = htonl(key_1);

	cache_item_t* item;
	HASH_FIND_INT(ctxt->requested_items, &key, item);
	if(item == NULL) {
		item = (cache_item_t*)rte_zmalloc(NULL, sizeof(cache_item_t), 0);
		item->key = key;
		HASH_ADD_INT(ctxt->requested_items, key, item);
	}
	item->vaddr = vaddr;
	item->paddr = paddr;
	item->freq++;
}

static __rte_always_inline void
rx_check_timer(cache_context_t* ctxt) {
	uint64_t now = rte_rdtsc_precise();
	uint64_t elapsed_ms = (double)(now - ctxt->last_ts) * 1E3 / rte_get_tsc_hz();
	if(elapsed_ms >= STATS_ITVL_MS_CACHE) {
		ctxt->current_hit_rate = (ctxt->rx_stats[ctxt->num_samples].rx_total > 0) ? ctxt->rx_stats[ctxt->num_samples].rx_hits * 1.0f / ctxt->rx_stats[ctxt->num_samples].rx_total : 0;
	}
	if(elapsed_ms >= STATS_ITVL_MS_CACHE && ctxt->num_samples < MAX_SAMPLES_CACHE) {
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] cache hits %u total %u\n", ctxt->rx_stats[ctxt->num_samples].rx_hits, ctxt->rx_stats[ctxt->num_samples].rx_total);
		ctxt->last_ts = now;
		ctxt->rx_stats[ctxt->num_samples].ts = (double)(now - ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
		ctxt->num_samples++;
	}
}

static __rte_always_inline void
rx_update_state(cache_context_t* ctxt, activep4_data_t* args) {

	if(args == NULL) {
		printf("Error: arguments not present!\n");
		return;
	}
    
    uint32_t cached_value = ntohl(args->data[ACTIVE_DEFAULT_ARG_RESULT]);

	#ifdef DEBUG_CACHE
	if(cached_value == 0) {
		uint32_t addr = ntohl(args->data[ACTIVE_DEFAULT_ARG_MAR]);
		uint32_t key_0 = ntohl(args->data[ACTIVE_DEFAULT_ARG_MBR]);
		uint32_t key_1 = ntohl(args->data[ACTIVE_DEFAULT_ARG_MBR2]);
		uint64_t key = (uint64_t)key_0 << 32 | key_1;
		cache_debug_t* item;
		HASH_FIND_INT(ctxt->debug, &key, item);
		if(item == NULL) {
			item = (cache_debug_t*)rte_zmalloc(NULL, sizeof(cache_debug_t), 0);
			item->addr = addr;
			item->key = key;
			item->key_0 = key_0;
			item->key_1 = key_1;
			item->value = cached_value;
			HASH_ADD_INT(ctxt->debug, key, item);
		}
	} else {
		// if(cached_value != 1) printf("Unexpected value at %u: %u\n", ntohl(args->data[ACTIVE_DEFAULT_ARG_MAR]), cached_value);
	}
	#endif

    if(cached_value != 0) ctxt->rx_stats[ctxt->num_samples].rx_hits++;
	ctxt->rx_stats[ctxt->num_samples].rx_total++;

	rx_check_timer(ctxt);
}

static __rte_always_inline void
rx_update_state_inactive(cache_context_t* ctxt) {

	ctxt->rx_stats[ctxt->num_samples].rx_total++;

	rx_check_timer(ctxt);
}

#endif