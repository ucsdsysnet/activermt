/**
 * @file common.h
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

#ifndef COMMON_H
#define COMMON_H

#include "../../../../../ref/uthash/include/uthash.h"
#include "../../../../../include/c/common/activep4.h"

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
	int					monitor_stgid_threshold;
	int					monitor_stgid_key_0;
	int					monitor_stgid_key_1;
	uint8_t				frequent_item_monitor;
	cache_item_t*		frequent_items;
	int					num_frequent_items;
} cache_context_t;

void context_switch_cache(activep4_context_t*);
void context_switch_monitor(activep4_context_t*);

#endif