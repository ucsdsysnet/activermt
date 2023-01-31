#ifndef ACTIVE_CACHE_H
#define ACTIVE_CACHE_H

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
#include <rte_hash_crc.h>

#include "../../headers/activep4.h"
#include "./include/types.h"
#include "./include/utils.h"
#include "./include/memory.h"
#include "./include/active.h"
#include "./include/common.h"

#include "active_hh.h"

#define MAX_SAMPLES_CACHE	100000
#define MAX_KEY				65535
#define STATS_ITVL_MS_CACHE	1
#define HH_COMPUTE_ITVL_SEC	1
#define PAYLOAD_MINLENGTH	8

void switch_context_cache(activep4_context_t*);
void switch_context_hh(activep4_context_t*);

// typedef struct {
// 	uint32_t	key;
// 	uint32_t	freq;
// } cache_item_freq_t;

typedef struct {
	uint64_t			ts;
	uint32_t			rx_hits;
	uint32_t			rx_total;
} cache_stats_t;

typedef struct {
	uint64_t			ts_ref;
	uint64_t			last_ts;
	// uint64_t			last_computed_freq;
	cache_stats_t		rx_stats[MAX_SAMPLES_CACHE];
	uint32_t			num_samples;
	int					stage_id_key_0;
	int					stage_id_key_1;
	int					stage_id_value;
	uint32_t			memory_start;
	int					memory_size;
	// cache_item_freq_t	frequency[MAX_KEY];
} cache_context_t;

void shutdown_cache(int id, void* context) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	if(cache_ctxt->num_samples == 0) return;
	char filename[50];
	sprintf(filename, "cache_rx_stats_%d.csv", id);
	FILE* fp = fopen(filename, "w");
	for(int i = 0; i < cache_ctxt->num_samples; i++) {
		fprintf(fp, "%lu,%u,%u\n", cache_ctxt->rx_stats[i].ts, cache_ctxt->rx_stats[i].rx_hits, cache_ctxt->rx_stats[i].rx_total);
	}
	fclose(fp);
}

void tx_mux_cache(void* inet_hdrs, void* context, int* pid) {}

void payload_parser_cache(void* inet_bufptr, activep4_data_t* ap4data, memory_t* alloc, void* context) {
	
	char* bufptr = (char*)inet_bufptr;

	struct rte_ipv4_hdr* hdr_ipv4 = (struct rte_ipv4_hdr*)bufptr;
    if(hdr_ipv4->next_proto_id != IPPROTO_UDP) return;

    struct rte_udp_hdr* hdr_udp = (struct rte_udp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));
    char* payload = bufptr + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr);

	// int payload_length = 0;
	// if(payload_length < sizeof(uint32_t)) return;

	// uint32_t* key = (uint32_t*)payload;

	uint32_t* key_0 = (uint32_t*)payload;
	uint32_t* key_1 = (uint32_t*)(payload + sizeof(uint32_t));

	uint64_t* key = (uint64_t*)payload;
	
	cache_context_t* cache_ctxt = (cache_context_t*)context;

	memset(ap4data, 0, sizeof(activep4_data_t));
	
	if(cache_ctxt->memory_size < 2) return;

	uint32_t vaddr = rte_hash_crc_8byte(*key, 0);
	uint32_t paddr = cache_ctxt->memory_start + vaddr % cache_ctxt->memory_size;
	
	ap4data->data[ACTIVE_DEFAULT_ARG_MAR] = htonl(paddr);
	ap4data->data[ACTIVE_DEFAULT_ARG_MBR] = htonl(*key_0);
	ap4data->data[ACTIVE_DEFAULT_ARG_MBR2] = htonl(*key_1);
}

void active_rx_handler_cache(void* active_context, activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	inet_pkt_t* inet_pkt = (inet_pkt_t*)pkt;
	if(inet_pkt->payload_length < PAYLOAD_MINLENGTH) return;
	if(ap4args == NULL) {
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[ERROR] cache arguments not present!\n");
		return;
	}
	uint32_t cached_value = ntohl(ap4args->data[ACTIVE_DEFAULT_ARG_RESULT]);
	// uint32_t key = ntohl(ap4args->data[1]);
	// uint32_t freq = ntohl(ap4args->data[3]);
	// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] key %u frequency %u\n", key, freq);
	if(cached_value != 0) {
		cache_ctxt->rx_stats[cache_ctxt->num_samples].rx_hits++;
		uint32_t* hm_flag = (uint32_t*)(inet_pkt->payload + sizeof(uint64_t) + sizeof(uint32_t));
		*hm_flag = 1;
		inet_pkt->hdr_udp->dgram_cksum = 0;
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[RXHDL] hit IP src %x dst %x UDP src %d dst %d \n", ntohl(inet_pkt->hdr_ipv4->src_addr), ntohl(inet_pkt->hdr_ipv4->dst_addr), ntohs(inet_pkt->hdr_udp->src_port), ntohs(inet_pkt->hdr_udp->dst_port));
	} else {
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[RXHDL] miss IP src %x dst %x UDP src %d dst %d \n", ntohl(inet_pkt->hdr_ipv4->src_addr), ntohl(inet_pkt->hdr_ipv4->dst_addr), ntohs(inet_pkt->hdr_udp->src_port), ntohs(inet_pkt->hdr_udp->dst_port));
	}
	cache_ctxt->rx_stats[cache_ctxt->num_samples].rx_total++;
	#ifdef STATS
	uint64_t now = rte_rdtsc_precise();
	uint64_t elapsed_ms = (double)(now - cache_ctxt->last_ts) * 1E3 / rte_get_tsc_hz();
	if(elapsed_ms >= STATS_ITVL_MS_CACHE && cache_ctxt->num_samples < MAX_SAMPLES_CACHE) {
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] cache hits %u total %u\n", cache_ctxt->rx_hits[cache_ctxt->num_samples], cache_ctxt->rx_total[cache_ctxt->num_samples]);
		cache_ctxt->last_ts = now;
		cache_ctxt->rx_stats[cache_ctxt->num_samples].ts = (double)(now - cache_ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
		cache_ctxt->num_samples++;
	}
	#endif
	#ifdef DEBUG
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Cache response: flags %x args (%u,%u,%u,%u)\n", ntohs(ap4ih->flags), ntohl(ap4args->data[0]), ntohl(ap4args->data[1]), ntohl(ap4args->data[2]), ntohl(ap4args->data[3]));
	#endif
}

int memory_consume_cache(memory_t* mem, void* context) { return 0; }

int memory_invalidate_cache(memory_t* mem, void* context) { return 0; }

int memory_reset_cache(memory_t* mem, void* context) {

	cache_context_t* cache_ctxt = (cache_context_t*)context;

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
	if(mem_end < mem->sync_data[cache_ctxt->stage_id_key_1].mem_end) mem_end = mem->sync_data[cache_ctxt->stage_id_key_1].mem_end;
	if(mem_end < mem->sync_data[cache_ctxt->stage_id_value].mem_end) mem_end = mem->sync_data[cache_ctxt->stage_id_value].mem_end;

	int memory_size = mem_end - mem_start + 1;

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[CACHE] effective memory size: %d\n", memory_size);

	cache_ctxt->memory_start = mem_start;
	cache_ctxt->memory_size = memory_size;

	return 0; 
}

void timer_cache(void* arg) {}

// void switch_context_cache(activep4_context_t* ctxt) {
// 	ctxt->is_active = 0;
// 	ctxt->tx_handler = payload_parser_cache;
// 	ctxt->rx_handler = active_rx_handler_cache;
// 	ctxt->memory_consume = memory_consume_cache;
// 	ctxt->memory_invalidate = memory_invalidate_cache;
// 	ctxt->memory_reset = memory_reset_cache;
// 	ctxt->shutdown = shutdown_cache;
// 	ctxt->timer = timer_cache;
// 	ctxt->is_active = 0;
// }

// void switch_context_hh(activep4_context_t* ctxt) {
// 	ctxt->tx_handler = active_tx_handler_hh;
// 	ctxt->rx_handler = active_rx_handler_hh;
// 	ctxt->memory_consume = memory_consume_hh;
// 	ctxt->memory_invalidate = memory_invalidate_hh;
// 	ctxt->memory_reset = memory_reset_hh;
// 	ctxt->shutdown = shutdown_hh;
// 	ctxt->timer = timer_hh;
// 	ctxt->timer_interval_us = 1000000;
// 	ctxt->active_timer_enabled = true;
// }

#endif