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
#include <rte_pdump.h>

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

typedef struct {
	uint32_t	key;
	uint32_t	freq;
} cache_item_freq_t;

typedef struct {
	uint64_t			ts_ref;
	uint64_t			last_ts;
	uint64_t			last_computed_freq;
	uint64_t			ts[MAX_SAMPLES_CACHE];
	uint32_t			rx_hits[MAX_SAMPLES_CACHE];
	uint32_t			rx_total[MAX_SAMPLES_CACHE];
	uint32_t			num_samples;
	int					stage_id_key;
	int					stage_id_value;
	cache_item_freq_t	frequency[MAX_KEY];
} cache_context_t;

void shutdown_cache(int id, void* context) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	if(cache_ctxt->num_samples == 0) return;
	char filename[50];
	sprintf(filename, "cache_stats_%d.csv", id);
	FILE* fp = fopen(filename, "w");
	for(int i = 0; i < cache_ctxt->num_samples; i++) {
		fprintf(fp, "%lu,%u,%u\n", cache_ctxt->ts[i], cache_ctxt->rx_hits[i], cache_ctxt->rx_total[i]);
	}
	fclose(fp);
}

void payload_parser_cache(void* inet_hdrs, activep4_data_t* ap4data, memory_t* alloc, void* context) {
	inet_pkt_t* hdrs = (inet_pkt_t*)inet_hdrs;
	char* payload = hdrs->payload;
	int payload_length = hdrs->payload_length;
	if(payload_length < sizeof(uint32_t)) return;
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	memset(ap4data, 0, sizeof(activep4_data_t));
	uint32_t* key = (uint32_t*)payload;
	int stage_id_key = -1, stage_id_value = -1;
	for(int i = 0; i < NUM_STAGES; i++) {
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
	uint32_t hh_threshold = 0;
	// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Key %d addr %d\n", *key, addr);
	ap4data->data[0] = htonl(addr);
	ap4data->data[1] = htonl(*key);
	ap4data->data[3] = htonl(hh_threshold);
}

void active_rx_handler_cache(void* active_context, activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	inet_pkt_t* inet_pkt = (inet_pkt_t*)pkt;
	if(inet_pkt->payload_length < PAYLOAD_MINLENGTH) return;
	if(ap4args == NULL) {
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[ERROR] cache arguments not present!\n");
		return;
	}
	uint32_t cached_value = ntohl(ap4args->data[0]);
	uint32_t key = ntohl(ap4args->data[1]);
	uint32_t freq = ntohl(ap4args->data[3]);
	// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] key %u frequency %u\n", key, freq);
	if(cached_value != 0) {
		cache_ctxt->rx_hits[cache_ctxt->num_samples]++;
		uint32_t* hm_flag = (uint32_t*)(inet_pkt->payload + sizeof(uint32_t));
		*hm_flag = 1;
		inet_pkt->hdr_udp->dgram_cksum = 0;
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[RXHDL] hit IP src %x dst %x UDP src %d dst %d \n", ntohl(inet_pkt->hdr_ipv4->src_addr), ntohl(inet_pkt->hdr_ipv4->dst_addr), ntohs(inet_pkt->hdr_udp->src_port), ntohs(inet_pkt->hdr_udp->dst_port));
	} else {
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[RXHDL] miss IP src %x dst %x UDP src %d dst %d \n", ntohl(inet_pkt->hdr_ipv4->src_addr), ntohl(inet_pkt->hdr_ipv4->dst_addr), ntohs(inet_pkt->hdr_udp->src_port), ntohs(inet_pkt->hdr_udp->dst_port));
	}
	#ifdef STATS
	cache_ctxt->rx_total[cache_ctxt->num_samples]++;
	uint64_t now = rte_rdtsc_precise();
	uint64_t elapsed_ms = (double)(now - cache_ctxt->last_ts) * 1E3 / rte_get_tsc_hz();
	if(elapsed_ms >= STATS_ITVL_MS_CACHE && cache_ctxt->num_samples < MAX_SAMPLES_CACHE) {
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] cache hits %u total %u\n", cache_ctxt->rx_hits[cache_ctxt->num_samples], cache_ctxt->rx_total[cache_ctxt->num_samples]);
		cache_ctxt->last_ts = now;
		cache_ctxt->ts[cache_ctxt->num_samples] = (double)(now - cache_ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
		cache_ctxt->num_samples++;
	}
	#endif
	#ifdef DEBUG
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Cache response: flags %x args (%u,%u,%u,%u)\n", ntohs(ap4ih->flags), ntohl(ap4args->data[0]), ntohl(ap4args->data[1]), ntohl(ap4args->data[2]), ntohl(ap4args->data[3]));
	#endif
}

int memory_consume_cache(memory_t* mem, void* context) { return 0; }

int memory_invalidate_cache(memory_t* mem, void* context) { return 0; }

int memory_reset_cache(memory_t* mem, void* context) { return 0; }

void timer_cache(void* arg) {}

void switch_context_cache(activep4_context_t* ctxt) {
	ctxt->is_active = 0;
	ctxt->tx_handler = payload_parser_cache;
	ctxt->rx_handler = active_rx_handler_cache;
	ctxt->memory_consume = memory_consume_cache;
	ctxt->memory_invalidate = memory_invalidate_cache;
	ctxt->memory_reset = memory_reset_cache;
	ctxt->shutdown = shutdown_cache;
	ctxt->timer = timer_cache;
	ctxt->is_active = 0;
}

void switch_context_hh(activep4_context_t* ctxt) {
	ctxt->tx_handler = active_tx_handler_hh;
	ctxt->rx_handler = active_rx_handler_hh;
	ctxt->memory_consume = memory_consume_hh;
	ctxt->memory_invalidate = memory_invalidate_hh;
	ctxt->memory_reset = memory_reset_hh;
	ctxt->shutdown = shutdown_hh;
	ctxt->timer = timer_hh;
	ctxt->timer_interval_us = 1000000;
	ctxt->active_timer_enabled = true;
}

#endif