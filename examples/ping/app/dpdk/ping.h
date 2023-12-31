/**
 * @file ping.h
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

#ifndef PING_H
#define PING_H

#include <rte_common.h>
#include <rte_hash_crc.h>
#include <rte_malloc.h>
#include <rte_timer.h>
#include <rte_memcpy.h>

#include "../../../../include/c/common/activep4.h"

#define DEBUG_PING
#define MAX_SAMPLES 		100000
#define APP_IPV4_ADDR     	0x0100000a

typedef struct {
	int			num_samples;
	uint64_t	ping_times_ns[MAX_SAMPLES];
} ping_context_t;

void 
shutdown_ping(int id, void* context) {
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Shutting down ping ... \n", id);
	ping_context_t* ping_ctxt = (ping_context_t*)context;
	if(ping_ctxt->num_samples == 0) return;
    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Writing %d samples written to ping_stats.csv ... \n", id, ping_ctxt->num_samples);
	FILE* fp = fopen("ping_stats.csv", "w");
	for(int i = 0; i < ping_ctxt->num_samples; i++) {
		fprintf(fp, "%lu\n", ping_ctxt->ping_times_ns[i]);
	}
	fclose(fp);
}

int 
memory_consume_ping(memory_t* mem, void* context) { return 0; }

int 
memory_invalidate_ping(memory_t* mem, void* context) { 

	for(int i = 0; i < NUM_STAGES; i++) {
		memset(mem->sync_data[i].data, 0, sizeof(uint32_t) * MAX_DATA);
	}

	rte_memcpy(mem->syncmap, mem->valid_stages, NUM_STAGES);

	return 1; 
}

int 
memory_reset_ping(memory_t* mem, void* context) { return 0; }

void 
timer_ping(void* arg) {
	// TODO: compute average ping time every second.
}

void
on_allocation_ping(void* arg) {}

#endif