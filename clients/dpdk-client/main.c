/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright(c) 2010-2015 Intel Corporation
 */

//#define DEBUG
#define PDUMP_ENABLE

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
#include <ncurses.h>
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

#define CLIENT
#define HH_DETECTION
#define MEMMGMT_CLIENT		1
#define INSTR_SET_PATH		"opcode_action_mapping.csv"
#define MAX_SAMPLES_CACHE	100000
#define MAX_KEY				65535
#define STATS_ITVL_MS_CACHE	1
#define HH_COMPUTE_ITVL_SEC	1
#define PAYLOAD_MINLENGTH	8

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

void payload_parser_cache(char* payload, int payload_length, activep4_data_t* ap4data, memory_t* alloc, void* context) {
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

void active_rx_handler_cache(activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {
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

void memory_consume_cache(memory_t* mem, void* context) {}

void memory_invalidate_cache(memory_t* mem, void* context) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	clear_memory_regions(mem);
}

void memory_reset_cache(memory_t* mem, void* context) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	#ifndef CLIENT
	clear_memory_regions(mem);
	#endif
	#ifndef HH_DETECTION
	int stage_id_key = -1, stage_id_value = -1;
	for(int i = 0; i < NUM_STAGES; i++) {
		if(!mem->valid_stages[i]) continue;
		if(stage_id_key < 0) stage_id_key = i;
		else {
			stage_id_value = i;
			break;
		}
	}
	if(mem->valid_stages[stage_id_key] && mem->valid_stages[stage_id_value]) {
		uint32_t memsize_keys = mem->sync_data[stage_id_key].mem_end - mem->sync_data[stage_id_key].mem_start + 1;
		uint32_t memsize_values = mem->sync_data[stage_id_value].mem_end - mem->sync_data[stage_id_value].mem_start + 1;
		uint32_t memsize = (memsize_keys < memsize_values) ? memsize_keys : memsize_values;
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] remapping %d memory objects in stages (%d,%d) from base address %u.\n", memsize, stage_id_key, stage_id_value, mem->sync_data[stage_id_key].mem_start);
		for(int i = 0; i < memsize; i++) {
			uint16_t addr = (uint16_t)i + mem->sync_data[stage_id_key].mem_start;
			mem->sync_data[stage_id_key].data[addr] = i;
			mem->sync_data[stage_id_value].data[addr] = i;
		}
	}
	#endif
}

int
main(int argc, char** argv)
{
	if(argc < 3) {
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Usage: %s <iface> <config_file>\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	is_running = 1;
	signal(SIGINT, interrupt_handler);

	char* dev = argv[1];
	char* config_filename = argv[2];

	int ret = rte_eal_init(argc, argv);

	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

	cache_context_t* cache_ctxt = (cache_context_t*)rte_zmalloc(NULL, MAX_INSTANCES * sizeof(cache_context_t), 0);
	if(cache_ctxt == NULL) {
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Unable to allocate memory for cache context!\n");
		exit(EXIT_FAILURE);
	}
	uint64_t ts_ref = rte_rdtsc_precise();
	for(int i = 0; i < MAX_INSTANCES; i++) {
		cache_ctxt[i].ts_ref = ts_ref;
	}

	active_handlers_t handlers[MAX_APPS];

	strcpy(handlers[0].appname, "cache_cms_hh");
	handlers[0].tx_handler = payload_parser_cache;
	handlers[0].rx_handler = active_rx_handler_cache;
	handlers[0].memory_consume = memory_consume_cache;
	handlers[0].memory_invalidate = memory_invalidate_cache;
	handlers[0].memory_reset = memory_reset_cache;
	handlers[0].shutdown = shutdown_cache;

	active_client_init(config_filename, dev, INSTR_SET_PATH, handlers, cache_ctxt);

	#ifdef PDUMP_ENABLE
	if(rte_pdump_init() < 0) {
		rte_exit(EXIT_FAILURE, "Unable to initialize packet capture.");
	}
	#endif

	lcore_main();

	active_client_shutdown();

	rte_eal_cleanup();

	return 0;
}
