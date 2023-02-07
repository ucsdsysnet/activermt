#ifndef CACHE_H
#define CACHE_H

#include <rte_common.h>

#include "../../../../ref/uthash/include/uthash.h"
#include "../../../../headers/activep4.h"

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

    uint64_t key = ctxt->keydist[ctxt->current_key_idx];

    ctxt->current_key_idx = (ctxt->current_key_idx + 1) % ctxt->distsize;

    uint32_t key_0 = key >> 32;;
	uint32_t key_1 = key & 0xFFFFFFFF;

    args->data[0] = 0;
    args->data[1] = htonl(key_0);
    args->data[2] = htonl(key_1);
}

#endif