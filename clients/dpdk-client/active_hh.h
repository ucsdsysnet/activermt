#ifndef ACTIVE_HH_H
#define ACTIVE_HH_H

#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <signal.h>
#include <stddef.h>
#include <inttypes.h>
#include <getopt.h>
#include <regex.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_mbuf_dyn.h>
#include <rte_compat.h>
#include <rte_memory.h>
#include <rte_malloc.h>
#include <rte_log.h>
#include <rte_pdump.h>

#include "../../headers/activep4.h"
#include "./include/types.h"
#include "./include/utils.h"
#include "./include/memory.h"
#include "./include/active.h"
#include "./include/common.h"

// #define DEBUG_HH

#define CMS_HH_SIZE         2
#define CMS_FILTER_SIZE     2
#define KEYSPACE		    65536
#define THRESH_TIMEOUT_SEC  5

int compare_elements(const void * a, const void * b) {
   return ( *(int*)b - *(int*)a );
}

typedef struct {
    uint8_t             sync_enabled;
    uint8_t             threshold_determined;
    uint32_t            hh_threshold;
    int                 top_k;
    uint64_t            last_computed_threshold;
    uint64_t			last_computed_freq;
    int 				stage_id_cms_hh[CMS_HH_SIZE];
    uint32_t			hh_items[KEYSPACE];
    uint32_t            filter_counts[KEYSPACE * CMS_FILTER_SIZE];
    int					num_hh;
    int                 num_counts;
} hh_context_t;

void shutdown_hh(int id, void* context) {}

void tx_mux_hh(void* inet_hdrs, void* context, int* pid) {}

void active_tx_handler_hh(void* inet_bufptr, activep4_data_t* ap4data, memory_t* alloc, void* context) {
    hh_context_t* hh_ctxt = (hh_context_t*)context;
    char* bufptr = (char*)inet_bufptr;

    struct rte_ipv4_hdr* hdr_ipv4 = (struct rte_ipv4_hdr*)bufptr;
    if(hdr_ipv4->next_proto_id != IPPROTO_UDP) return;

    struct rte_udp_hdr* hdr_udp = (struct rte_udp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));
    char* payload = bufptr + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr);

    memset(ap4data, 0, sizeof(activep4_data_t));
    uint32_t* key = (uint32_t*)payload;
	int stage_id_key = -1, stage_id_value = -1;
	for(int i = NUM_STAGES - 1; i >= 0; i--) {
		if(!alloc->valid_stages[i]) continue;
		if(stage_id_key < 0) stage_id_key = i;
		else {
			stage_id_value = i;
			break;
		}
	}
	uint32_t memsize_keys = alloc->sync_data[stage_id_key].mem_end - alloc->sync_data[stage_id_key].mem_start + 1;
	uint32_t memsize_values = alloc->sync_data[stage_id_value].mem_end - alloc->sync_data[stage_id_value].mem_start + 1;
	int memory_size = (memsize_keys < memsize_values) ? memsize_keys : memsize_values;
	if(memory_size < 2) return;
    uint16_t addr = alloc->sync_data[stage_id_key].mem_start + (*key % memory_size);
    ap4data->data[0] = htonl(*key);
	ap4data->data[1] = htonl(hh_ctxt->hh_threshold);
    ap4data->data[2] = htonl((uint32_t)addr);
    // printf("key %d address %d\n", *key, addr);
}

void active_rx_handler_hh(void* active_context, activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {}

int memory_consume_hh(memory_t* mem, void* context) { 
    hh_context_t* hh_ctxt = (hh_context_t*)context;
    if(hh_ctxt->threshold_determined == 0) {
        int num_counts = 0;
        for(int i = 0, d = 0; i < NUM_STAGES && d < CMS_FILTER_SIZE; i++) {
            if(mem->valid_stages[i] == 1) {
                int stage_id = i;
                int mem_start = mem->sync_data[stage_id].mem_start;
                int mem_end = mem->sync_data[stage_id].mem_end;
                for(int j = mem_start; j <= mem_end; j++) {
                    uint32_t count = mem->sync_data[stage_id].data[j];
                    if(count > 0) {
                        hh_ctxt->filter_counts[num_counts++] = count;
                    }
                }
            }
        }
        // TODO use techniques from Sketchlib or HashPipe.
        // qsort((void*)&hh_ctxt->filter_counts, num_counts, sizeof(uint32_t), compare_elements);
        // hh_ctxt->hh_threshold = hh_ctxt->filter_counts[hh_ctxt->top_k - 1];
        hh_ctxt->hh_threshold = 10;
        hh_ctxt->num_counts = num_counts;
        hh_ctxt->threshold_determined = 1;
        hh_ctxt->last_computed_threshold = rte_rdtsc_precise();
        #ifdef DEBUG_HH
        printf("Threshold determined for top %d items (from %d counter values) = %d (max count %d)\n", hh_ctxt->top_k, num_counts, hh_ctxt->hh_threshold, hh_ctxt->filter_counts[0]);
        #endif
    } else {
        int num_keys = 0;
        for(int i = 0; i < CMS_HH_SIZE; i++) {
            int stage_id = hh_ctxt->stage_id_cms_hh[i];
            int mem_start = mem->sync_data[stage_id].mem_start;
            int mem_end = mem->sync_data[stage_id].mem_end;
            for(int j = mem_start; j <= mem_end; j++) {
                uint32_t key = mem->sync_data[stage_id].data[j];
                if(key > 0 && num_keys < KEYSPACE) {
                    hh_ctxt->hh_items[num_keys++] = key;
                }
            }
        }
        hh_ctxt->num_hh = num_keys;
        hh_ctxt->last_computed_freq = rte_rdtsc_precise();
        #ifdef DEBUG_HH
        printf("Number of HH items: %d\n", num_keys);
        #endif
    }
    return 0; 
}

int memory_invalidate_hh(memory_t* mem, void* context) {
    // clear both counters and stored keys.
    rte_memcpy(mem->syncmap, mem->valid_stages, NUM_STAGES);
    clear_memory_regions(mem);
    return 1; 
}

int memory_reset_hh(memory_t* mem, void* context) {
    hh_context_t* hh_ctxt = (hh_context_t*)context;
    int cms_idx = 0, memsize = MAX_DATA;
    for(int i = NUM_STAGES - 1; i >= 0  && cms_idx < CMS_HH_SIZE; i--) {
		if(!mem->valid_stages[i]) continue;
		hh_ctxt->stage_id_cms_hh[cms_idx++] = i;
        memsize = (memsize < (mem->sync_data[i].mem_end - mem->sync_data[i].mem_start + 1)) ? (mem->sync_data[i].mem_end - mem->sync_data[i].mem_start + 1) : memsize;
	}
    hh_ctxt->top_k = memsize;
    hh_ctxt->sync_enabled = 1;
    return 0; 
}

void timer_hh(void* arg) {
    activep4_context_t* ctxt = (activep4_context_t*)arg;
	hh_context_t* hh_ctxt = (hh_context_t*)ctxt->app_context;
    if(!hh_ctxt->sync_enabled) return;
    if((double)(rte_rdtsc_precise() - hh_ctxt->last_computed_threshold) / rte_get_tsc_hz() > THRESH_TIMEOUT_SEC)
        hh_ctxt->threshold_determined = 0;
    memset(ctxt->allocation.syncmap, 0, NUM_STAGES * sizeof(uint8_t));
    if(hh_ctxt->threshold_determined == 1) {
        // read only stored keys from switch once threshold is determined.
        for(int i = 0; i < CMS_HH_SIZE; i++) {
            ctxt->allocation.syncmap[hh_ctxt->stage_id_cms_hh[i]] = 1;
        }
    } else {
        // otherwise, read filter counters.
        for(int i = 0, d = 0; i < NUM_STAGES && d < CMS_FILTER_SIZE; i++) {
            if(ctxt->allocation.valid_stages[i] == 1){
                ctxt->allocation.syncmap[i] = 1;
                d++;
            }
        }
    }
	clear_memory_regions(&ctxt->allocation);
	ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
}

void static_allocation_hh(memory_t* mem) {
    int num_valid_stages = 4;
    int valid_stages[] = {5, 10, 11, 12};
    for(int i = 0; i < num_valid_stages; i++) {
        mem->valid_stages[valid_stages[i]] = 1;
        mem->sync_data[valid_stages[i]].mem_start = 0;
        mem->sync_data[valid_stages[i]].mem_end = MAX_DATA - 1;
    }
}

#endif