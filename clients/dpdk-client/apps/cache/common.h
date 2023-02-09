#ifndef COMMON_H
#define COMMON_H

#include "../../../../ref/uthash/include/uthash.h"
#include "../../../../headers/activep4.h"

#define PID_CACHEREAD		0
#define PID_FREQITEM		1
#define MAX_SAMPLES_CACHE	100000
#define STATS_ITVL_MS_CACHE	1
#define HH_ITVL_MIN_MS		100
#define HH_ITVL_MAX_MS		10000
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
	uint32_t		addr;
	uint64_t		key;
	uint32_t		key_0;
	uint32_t		key_1;
	uint32_t		value;
	UT_hash_handle	hh;
} cache_debug_t;

typedef struct {
	uint64_t			ts_ref;
	uint64_t			last_ts;
	cache_stats_t		rx_stats[MAX_SAMPLES_CACHE];
	uint32_t			num_samples;
    double              current_hit_rate;
    double              target_hit_rate;
	int					stage_id_key_0;
	int					stage_id_key_1;
	int					stage_id_value;
	uint32_t			memory_start;
	int					memory_size;
	cache_item_t*		requested_items;
	cache_debug_t*		debug;
	uint8_t				timer_reset_trigger;
    uint64_t*           keydist;
    int                 distsize;
    int                 current_key_idx;
    uint32_t            ipv4_dstaddr;
	uint16_t			app_port;
    uint8_t             timer_snapshot_trigger;
    uint8_t             timer_deallocate_trigger;
    uint8_t             timer_ctxswtch_trigger;
} cache_context_t;

void context_switch_cache(activep4_context_t*);
void context_switch_monitor(activep4_context_t*);

#endif