#ifndef CACHE_H
#define CACHE_H

#include <rte_common.h>
#include <rte_hash_crc.h>
#include <rte_malloc.h>
#include <rte_timer.h>
#include <rte_memcpy.h>

#include "../../../../ref/uthash/include/uthash.h"
#include "../../../../headers/activep4.h"

#define DEBUG_CACHE

#define MAX_SAMPLES_CACHE	100000
#define STATS_ITVL_MS_CACHE	1
#define HH_COMPUTE_ITVL_SEC	1
#define PAYLOAD_MINLENGTH	16
#define MAX_CACHE_SIZE		100000

typedef struct {
	uint32_t		vaddr;
	uint32_t		paddr;
	uint64_t		key;
	uint32_t		value;
	uint32_t		freq;
	uint32_t		collisions;
	UT_hash_handle	hh;
} cache_item_t;

typedef struct {
	uint64_t			ts;
	uint32_t			rx_hits;
	uint32_t			rx_total;
} cache_stats_t;

typedef struct {
	uint64_t			ts_ref;
	uint64_t			last_ts;
	cache_stats_t		rx_stats[MAX_SAMPLES_CACHE];
	uint32_t			num_samples;
	int					stage_id_key_0;
	int					stage_id_key_1;
	int					stage_id_value;
	uint32_t			memory_start;
	int					memory_size;
	cache_item_t*		requested_items;
	uint8_t				timer_reset_trigger;
    uint64_t*           keydist;
    int                 distsize;
    int                 current_key_idx;
    uint32_t            ipv4_dstaddr;
} cache_context_t;

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

	HASH_SORT(cache_ctxt->requested_items, compare_elements_cache);

	memset(&ctxt->membuf, 0, sizeof(ctxt->membuf));

	int num_stored = 0, num_total = 0, max_freq = 0, estimated_hitrate = 0, sum_freq = 0;

	uint8_t bloom[MAX_CACHE_SIZE];
	memset(bloom, 0, MAX_CACHE_SIZE);

	cache_item_t* item;

	for(item = cache_ctxt->requested_items; item != NULL && num_stored < cache_ctxt->memory_size; item = item->hh.next) {
		// estimated_hitrate += item->freq;
		max_freq = (item->freq > max_freq) ? item->freq : max_freq;
		// uint32_t paddr = cache_ctxt->memory_start + item->vaddr % cache_ctxt->memory_size;
		uint32_t paddr = item->paddr;
		if(bloom[paddr]) continue;
		uint64_t key = item->key;
		uint32_t key_0 = key >> 32;
		uint32_t key_1 = key & 0xFFFFFFFF;
		assert(key_0 > 0 || key_1 > 0);
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

	rte_memcpy(ctxt->allocation.syncmap, ctxt->allocation.valid_stages, NUM_STAGES);

	// HASH_CLEAR(hh, cache_ctxt->requested_items);

	if(num_stored > 0) {
		cache_ctxt->timer_reset_trigger = 1;
		ctxt->status = ACTIVE_STATE_REMAPPING;
	}

	#ifdef DEBUG_CACHE
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Frequent items = %d, total items = %d, max frequency = %d\n", num_stored, num_total, max_freq);	
	#endif
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
rx_update_state(cache_context_t* ctxt, activep4_data_t* args) {
    
    uint32_t cached_value = ntohl(args->data[ACTIVE_DEFAULT_ARG_RESULT]);

    if(cached_value != 0) ctxt->rx_stats[ctxt->num_samples].rx_hits++;
	ctxt->rx_stats[ctxt->num_samples].rx_total++;

    uint64_t now = rte_rdtsc_precise();
	uint64_t elapsed_ms = (double)(now - ctxt->last_ts) * 1E3 / rte_get_tsc_hz();
	if(elapsed_ms >= STATS_ITVL_MS_CACHE && ctxt->num_samples < MAX_SAMPLES_CACHE) {
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] cache hits %u total %u\n", ctxt->rx_stats[ctxt->num_samples].rx_hits, ctxt->rx_stats[ctxt->num_samples].rx_total);
		ctxt->last_ts = now;
		ctxt->rx_stats[ctxt->num_samples].ts = (double)(now - ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
		ctxt->num_samples++;
	}
}

#endif