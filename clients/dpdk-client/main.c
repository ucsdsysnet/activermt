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
#include <rte_pdump.h>

#include "../../headers/activep4.h"
#include "./include/types.h"
#include "./include/utils.h"
#include "./include/memory.h"

#define MEMMGMT_CLIENT		1
#define INSTR_SET_PATH		"opcode_action_mapping.csv"
#define MAX_SAMPLES_CACHE	100000
#define STATS_ITVL_MS_CACHE	1

static struct rte_eth_dev_tx_buffer* buffer;
static uint64_t drop_counter;
static int is_running;

static void interrupt_handler(int sig) {
    is_running = 0;
}

/*static const char usage[] =
	"%s EAL_ARGS -- [-t]\n";*/

static inline void insert_active_program_headers(activep4_context_t* ap4_ctxt, struct rte_mbuf* pkt) {
	
	char* bufptr = rte_pktmbuf_mtod(pkt, char*);
	
	struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
	hdr_eth->ether_type = htons(AP4_ETHER_TYPE_AP4);

	int ap4hlen = sizeof(activep4_ih) + sizeof(activep4_data_t) + (ap4_ctxt->program->proglen * sizeof(activep4_instr));

	for(int i = pkt->pkt_len - 1; i >= sizeof(struct rte_ether_hdr); i--) {
		bufptr[i + ap4hlen] = bufptr[i];
	}

	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS);
	ap4ih->fid = htons(ap4_ctxt->program->fid);
	ap4ih->seq = htons(0);

	char* payload = NULL;
	int payload_length = 0;

	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + ap4hlen);
	if(iph->next_proto_id == IPPROTO_UDP) {
		payload = bufptr + sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr) + ap4hlen;
		payload_length = pkt->pkt_len - (sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr));
	} else if(iph->next_proto_id == IPPROTO_TCP) {
		payload = bufptr + sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_tcp_hdr) + ap4hlen;
		payload_length = pkt->pkt_len - (sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_tcp_hdr));
	}

	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	ap4_ctxt->payload_parser(payload, payload_length, ap4data, &ap4_ctxt->allocation, ap4_ctxt->app_context);

	for(int i = 0; i < ap4_ctxt->program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = ap4_ctxt->program->code[i].flags;
		instr->opcode = ap4_ctxt->program->code[i].opcode;
	}

	pkt->pkt_len += ap4hlen;
	pkt->data_len += ap4hlen;
}

/*
	Context is defined by an application source-destination port pair.
	Created when application traffic is seen on the interface. 
	Assigned an instance from a pool of FIDs.
	TODO: control traffic should be started only when an app context is created. 
*/
static inline activep4_context_t* get_app_context_from_packet(char* bufptr, active_apps_t* apps_ctxt) {
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)bufptr;
	uint32_t app_id = 0, instance_id = 0;
	activep4_context_t* ctxt = NULL;
	if(iph->next_proto_id == IPPROTO_UDP) {
		struct rte_udp_hdr* udph = (struct rte_udp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));
		app_id = ntohs(udph->dst_port);
		instance_id = (app_id << 16) | ntohs(udph->src_port);
	} else if(iph->next_proto_id == IPPROTO_TCP) {
		struct rte_tcp_hdr* tcph = (struct rte_tcp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));
		app_id = ntohs(tcph->dst_port);
		instance_id = (app_id << 16) | ntohs(tcph->src_port);
	} else return NULL;
	int empty_slot = -1;
	for(int j = 0; j < apps_ctxt->num_apps_instances; j++) {
		if(apps_ctxt->app_id[j] == app_id) {
			if(apps_ctxt->instance_id[j] == instance_id) {
				ctxt = &apps_ctxt->ctxt[j];
			} else if(apps_ctxt->instance_id[j] == 0 && empty_slot < 0) empty_slot = j;
		}
	}
	if(ctxt == NULL && empty_slot >= 0) {
		apps_ctxt->instance_id[empty_slot] = instance_id;
		ctxt = &apps_ctxt->ctxt[empty_slot];
		ctxt->is_active = true;
		printf("[INFO] Created application context for FID %d with instance ID %d.\n", ctxt->program->fid, instance_id);
		assert(ctxt != NULL);
	}
	return ctxt;
}

static uint16_t
active_encap_filter(
	uint16_t port_id __rte_unused, 
	uint16_t queue __rte_unused, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	uint16_t max_pkts,
	void *ctxt
) {
	active_apps_t* apps_ctxt = (active_apps_t*)ctxt;

	for(int i = 0; i < nb_pkts; i++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[i], char*);
		struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
		if(eth->ether_type != htons(RTE_ETHER_TYPE_IPV4)) continue;
		activep4_context_t* ctxt = get_app_context_from_packet(bufptr + sizeof(struct rte_ether_hdr), apps_ctxt);
		if(ctxt == NULL) continue;
		switch(ctxt->status) {
			case ACTIVE_STATE_TRANSMITTING:
				insert_active_program_headers(ctxt, pkts[i]);
				break;
			default:
				break;
		}
	}

	return nb_pkts;
}

static uint16_t
active_decap_filter(
	uint16_t port_id __rte_unused, 
	uint16_t queue __rte_unused, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	void *ctxt
) {
	active_apps_t* apps_ctxt = (active_apps_t*)ctxt;

	for(int k = 0; k < nb_pkts; k++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[k], char*);
		struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
		int offset = 0;
		if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
			hdr_eth->ether_type = htons(RTE_ETHER_TYPE_IPV4);
			activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
			activep4_data_t* ap4data = NULL;
			if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
			uint16_t flags = ntohs(ap4ih->flags);
			uint16_t fid = ntohs(ap4ih->fid);
			uint16_t seq = ntohs(ap4ih->seq);
			// Strip packet of active headers.
			offset += sizeof(activep4_ih);
			if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
				ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
				offset += sizeof(activep4_data_t);
			}
			if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
				offset += sizeof(activep4_malloc_res_t);
			}
			if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_EOE)) {
				offset += get_active_eof(bufptr + sizeof(struct rte_ether_hdr) + offset, pkts[k]->pkt_len);
			}
			// Get active app context.
			activep4_context_t* ctxt = NULL;
			for(int i = 0; i < apps_ctxt->num_apps_instances; i++) {
				if(apps_ctxt->ctxt[i].program->fid == fid) ctxt = &apps_ctxt->ctxt[i];
			}
			if(ctxt == NULL) {
				printf("Unable to extract app context!\n");
				continue;
			}
			
			// Update control state.
			switch(ctxt->status) {
				case ACTIVE_STATE_INITIALIZING:
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REQALLOC)) {
						ctxt->status = ACTIVE_STATE_ALLOCATING;
					}
					break;
				case ACTIVE_STATE_REALLOCATING:
					// printf("[INFO] FID %d STATE %d Flags %x\n", ctxt->program->fid, ctxt->status, flags);
				case ACTIVE_STATE_ALLOCATING:
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
						if(ctxt->allocation.version != seq) {
							activep4_malloc_res_t* ap4malloc = (activep4_malloc_res_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
							ctxt->allocation.version = seq;
							ctxt->allocation.hash_function = NULL;
							printf("[ALLOCATION] FID %d (ver %d) ", fid, ctxt->allocation.version);
							for(int i = 0; i < NUM_STAGES; i++) {
								ctxt->allocation.sync_data[i].mem_start = ntohs(ap4malloc->mem_range[i].start);
								ctxt->allocation.sync_data[i].mem_end = ntohs(ap4malloc->mem_range[i].end);
								if((ctxt->allocation.sync_data[i].mem_end - ctxt->allocation.sync_data[i].mem_start) > 0) {
									ctxt->allocation.valid_stages[i] = 1;
									printf("{S%d: %d - %d} ", i, ctxt->allocation.sync_data[i].mem_start, ctxt->allocation.sync_data[i].mem_end);
								}
							}
							printf("\n");
							// TODO
							// ctxt->status = (ctxt->status == ACTIVE_STATE_ALLOCATING) ? ACTIVE_STATE_TRANSMITTING : ACTIVE_STATE_REMAPPING;
							ctxt->status = ACTIVE_STATE_REMAPPING;
							#ifdef DEBUG
							printf("[DEBUG] state %d\n", ctxt->status);
							#endif
						}
					}
					break;
				case ACTIVE_STATE_SNAPSHOTTING:
					if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS) && TEST_FLAG(flags, AP4FLAGMASK_FLAG_INITIATED)) {
						activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
						int mem_addr = ntohl(ap4data->data[0]);
						int mem_data = ntohl(ap4data->data[1]);
						int stage_id = ntohl(ap4data->data[2]);
						ctxt->allocation.sync_data[stage_id].data[mem_addr] = mem_data;
						ctxt->allocation.sync_data[stage_id].valid[mem_addr] = 1;
						// printf("[SNAPACK] stage %d index %d flags %x\n", stage_id, mem_addr, flags);
					}
					break;
				case ACTIVE_STATE_REMAPPING:
					if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
						if(ap4data != NULL) {
							int mem_addr = ntohl(ap4data->data[0]);
							int mem_data = ntohl(ap4data->data[1]);
							int stage_id = ntohl(ap4data->data[2]);
							ctxt->membuf.sync_data[stage_id].valid[mem_addr] = 1;	
						} else {
							printf("[ERROR] unable to parse args!\n");
						}
					}
					break;
				case ACTIVE_STATE_TRANSMITTING:
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REMAPPED) && ctxt->allocation.version == seq) {
						ctxt->allocation.sync_version = seq;
						for(int i = 0; i < NUM_STAGES; i++) {
							for(int j = 0; j < MAX_DATA; j++) {
								ctxt->allocation.sync_data[i].valid[j] = 0;
							}
						}
						ctxt->allocation.invalid = 1;
						ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
					}
					if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_MARKED))
						ctxt->rx_handler(ap4ih, ap4data, ctxt->app_context);
					// printf("pkt length %d\n", pkts[k]->pkt_len);
					break;
				case ACTIVE_STATE_SNAPCOMPLETING:
					printf("[SNAPCMPLT] FID %d Flags %x\n", fid, flags);
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ACK)) {
						// ctxt->status = ACTIVE_STATE_REALLOCATING;
						// printf("Snapshotting -> reallocating.\n");
					}
					break;
				default:
					break;
			}

			for(int i = 0; i < pkts[k]->pkt_len - sizeof(struct rte_ether_hdr) - offset; i++) {
				bufptr[sizeof(struct rte_ether_hdr) + i] = bufptr[sizeof(struct rte_ether_hdr) + offset + i];
			}
			pkts[k]->pkt_len -= offset;
			pkts[k]->data_len -= offset;
		} else {
			printf("[INFO] Non active packet: ");
			print_pktinfo(bufptr, pkts[k]->pkt_len);
		}
		
		// TODO update application state.
	}	

	return nb_pkts;
}

static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool, active_apps_t* apps_ctxt)
{
	struct rte_eth_conf port_conf;
	uint16_t nb_rxd = RX_RING_SIZE;
	uint16_t nb_txd = TX_RING_SIZE;
	int retval;
	uint16_t q;
	struct rte_eth_dev_info dev_info;
	struct rte_eth_rxconf rxconf;
	struct rte_eth_txconf txconf;

	if(!rte_eth_dev_is_valid_port(port))
		return -1;

	memset(&port_conf, 0, sizeof(struct rte_eth_conf));

	retval = rte_eth_dev_info_get(port, &dev_info);
	if (retval != 0) {
		printf("Error during getting device (port %u) info: %s\n", port, strerror(-retval));
		return retval;
	}

	const uint16_t rx_rings = (dev_info.max_rx_queues > 3) ? 4 : 1;
	const uint16_t tx_rings = (dev_info.max_tx_queues > 3) ? 4 : 1;

	if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_MBUF_FAST_FREE)
		port_conf.txmode.offloads |=
			RTE_ETH_TX_OFFLOAD_MBUF_FAST_FREE;

	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0)
		return retval;

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
		return retval;

	rxconf = dev_info.default_rxconf;

	for(q = 0; q < rx_rings; q++) {
		retval = rte_eth_rx_queue_setup(port, q, nb_rxd, rte_eth_dev_socket_id(port), &rxconf, mbuf_pool);
		if (retval < 0)
			return retval;
	}

	txconf = dev_info.default_txconf;
	txconf.offloads = port_conf.txmode.offloads;
	for (q = 0; q < tx_rings; q++) {
		retval = rte_eth_tx_queue_setup(port, q, nb_txd, rte_eth_dev_socket_id(port), &txconf);
		if(retval < 0)
			return retval;
	}

	retval = rte_eth_dev_start(port);
	if(retval < 0)
		return retval;

	struct rte_ether_addr addr;

	retval = rte_eth_macaddr_get(port, &addr);
	if (retval < 0) {
		printf("Failed to get MAC address on port %u: %s\n", port, rte_strerror(-retval));
		return retval;
	}
	printf(
		"Port %u MAC: %02"PRIx8" %02"PRIx8" %02"PRIx8" %02"PRIx8" %02"PRIx8" %02"PRIx8"\n",
		(unsigned)port,
		RTE_ETHER_ADDR_BYTES(&addr)
	);

	int is_virtual_dev = 0;
	if(strcmp(dev_info.driver_name, "net_virtio_user") == 0) {
		is_virtual_dev = 1;
	} else {
		retval = rte_eth_promiscuous_enable(port);
		if(retval != 0) return retval;
	}

	// Add filters to virtio interfaces.
	if(is_virtual_dev) {
		rte_eth_add_tx_callback(port, 0, active_decap_filter, (void*)apps_ctxt);
		rte_eth_add_rx_callback(port, 0, active_encap_filter, (void*)apps_ctxt);
	}

	return 0;
}

static void
lcore_main(void)
{
	uint16_t port;

	uint8_t vdev[RTE_MAX_ETHPORTS];
	memset(vdev, 0, RTE_MAX_ETHPORTS);

	RTE_ETH_FOREACH_DEV(port) {
		struct rte_eth_dev_info dev_info;
		if(rte_eth_dev_info_get(port, &dev_info) != 0) {
			printf("Error during getting device (port %u)\n", port);
			exit(EXIT_FAILURE);
		}
		if(strcmp(dev_info.driver_name, "net_virtio_user") == 0) {
			vdev[port] = 1;
		}
		if(rte_eth_dev_socket_id(port) > 0 && rte_eth_dev_socket_id(port) != (int)rte_socket_id()) {
			printf("WARNING, port %u is on remote NUMA node to polling thread.\n\tPerformance will not be optimal.\n", port);
		}
		else {
			printf("Port %d on local NUMA node.\n", port);
		}
		printf("Port %d Queues RX %d Tx %d\n", port, dev_info.nb_rx_queues, dev_info.nb_tx_queues);
	}

	printf("\nCore %u forwarding packets. [Ctrl+C to quit]\n", rte_lcore_id());

	const int qid = 0;

	while(is_running) {
		RTE_ETH_FOREACH_DEV(port) {
			struct rte_mbuf* bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(port, qid, bufs, BURST_SIZE);
			
			if (unlikely(nb_rx == 0))
				continue;

			uint16_t nb_tx = 0;

			#ifdef DEBUG
			printf("[PORT %d][RX] %d pkts.\n", port, nb_rx);
			for(int i = 0; i < nb_rx; i++) {
				char* pkt = rte_pktmbuf_mtod(bufs[i], char*);
				print_pktinfo(pkt, bufs[i]->pkt_len);
			}
			#endif

			nb_tx = rte_eth_tx_burst(port^1, qid, bufs, nb_rx);
			if(unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for(buf = nb_tx; buf < nb_rx; buf++)
					rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
}

static int
lcore_stats(void* arg) {
	
	unsigned lcore_id = rte_lcore_id();

	int port_id = *((int*)arg);

	active_dpdk_stats_t samples;
	memset(&samples, 0, sizeof(active_dpdk_stats_t));

	uint64_t last_ipackets = 0, last_opackets = 0;
	
	printf("Starting stats monitor for port %d on lcore %u ... \n", port_id, lcore_id);

	uint64_t ts_ref = rte_rdtsc_precise();

	while(is_running) {
		struct rte_eth_stats stats = {0};
		if(rte_eth_stats_get(port_id, &stats) == 0) {
			uint64_t rx_pkts = stats.ipackets - last_ipackets;
			uint64_t tx_pkts = stats.opackets - last_opackets;
			last_ipackets = stats.ipackets;
			last_opackets = stats.opackets;
			if(samples.num_samples < MAX_STATS_SAMPLES) {
				samples.ts[samples.num_samples] = (double)(rte_rdtsc_precise() - ts_ref) * 1E9 / rte_get_tsc_hz();
				samples.rx_pkts[samples.num_samples] = rx_pkts;
				samples.tx_pkts[samples.num_samples] = tx_pkts;
				samples.num_samples++;
			}
			#ifdef DEBUG
			if(rx_pkts > 0 || tx_pkts > 0)
				printf("[STATS][%d] RX %lu pkts TX %lu pkts\n", port_id, rx_pkts, tx_pkts);
			#endif
		}
		rte_delay_us_block(DELAY_SEC);
	}

	char filename[50];
	sprintf(filename, "dpdk_ap4_stats_%d.csv", port_id);
	FILE *fp = fopen(filename, "w");
	if(fp == NULL) return -1;
	for(int i = 0; i < samples.num_samples; i++) {
		fprintf(fp, "%lu,%lu,%lu\n", samples.ts[i], samples.rx_pkts[i], samples.tx_pkts[i]);
	}
	fclose(fp);
    printf("[STATS] %u samples written to %s.\n", samples.num_samples, filename);
	
	return 0;
}

static inline void construct_reqalloc_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_REQALLOC);
	ap4ih->fid = htons(ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_malloc_req_t* mreq = (activep4_malloc_req_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	mreq->proglen = htons((uint16_t)ctxt->program->proglen);
	mreq->iglim = (uint8_t)ctxt->program->iglim;
	for(int i = 0; i < ctxt->program->num_accesses; i++) {
		mreq->mem[i] = ctxt->program->access_idx[i];
		mreq->dem[i] = ctxt->program->demand[i];
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_getalloc_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr)); 
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_GETALLOC);
	ap4ih->fid = htons(ctxt->program->fid);
	ap4ih->seq = 0;
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_reallocate_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_ACK | AP4FLAGMASK_FLAG_GETALLOC);
	ap4ih->fid = htons(ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t* program = NULL;
	program = (activep4_def_t*)rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
	construct_nop_program(program, ctxt->instr_set, 0);
	if(program == NULL) {
		rte_exit(EXIT_FAILURE, "Could not construct completion program!\n");
		return;
	}
	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program->code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_snapshot_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt, int stage_id, int mem_addr, activep4_def_t* memsync_cache, bool complete) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = (complete) ? htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_ACK) : htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_INITIATED);
	ap4ih->fid = htons(ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t* program = NULL;
	if(complete) {
		program = (activep4_def_t*)rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
		construct_nop_program(program, ctxt->instr_set, 0);
	} else {
		ap4data->data[0] = htonl((uint32_t)mem_addr);
		ap4data->data[2] = htonl((uint32_t)stage_id);
		program = construct_memsync_program(ctxt->program->fid, stage_id, ctxt->instr_set, memsync_cache);
	}
	if(program == NULL) {
		rte_exit(EXIT_FAILURE, "Could not construct memsync/completion program!\n");
		return;
	}
	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program->code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_heartbeat_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_MARKED);
	ap4ih->fid = htons(ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t program = {0};
	construct_nop_program(&program, ctxt->instr_set, 0);
	for(int i = 0; i < program.proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program.code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program.proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program.proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_memremap_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt, int stage_id, int mem_addr, uint32_t data, activep4_def_t* memset_cache) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_INITIATED);
	ap4ih->fid = htons(ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	ap4data->data[0] = htonl((uint32_t)mem_addr);
	ap4data->data[1] = htonl(data);
	ap4data->data[2] = htonl((uint32_t)stage_id);
	activep4_def_t* program = construct_memset_program(ctxt->program->fid, stage_id, ctxt->instr_set, memset_cache);
	if(program == NULL) {
		printf("Could not construct memsync program!\n");
		return;
	}
	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program->code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static int
lcore_control(void* arg) {

	unsigned lcore_id = rte_lcore_id();

	const int qid = 1;

	active_control_t* ctrl = (active_control_t*)arg;

	printf("Starting controller for port %d on lcore %u ... \n", ctrl->port_id, lcore_id);

	struct rte_mbuf* mbuf;

	activep4_def_t memsync_cache[NUM_STAGES], memset_cache[NUM_STAGES];
	memset(memsync_cache, 0, NUM_STAGES * sizeof(activep4_def_t));
	memset(memset_cache, 0, NUM_STAGES * sizeof(activep4_def_t));

	uint64_t now, elapsed_us;
	int snapshotting_in_progress = 0, remapping_in_progress = 0;

	while(is_running) {
		now = rte_rdtsc_precise();
		for(int i = 0; i < ctrl->apps_ctxt->num_apps_instances; i++) {
			activep4_context_t* ctxt = &ctrl->apps_ctxt->ctxt[i];
			elapsed_us = (double)(now - ctxt->ctrl_ts_lastsent) * 1E6 / rte_get_tsc_hz();
			if(!ctxt->is_active) continue;
			switch(ctxt->status) {
				case ACTIVE_STATE_INITIALIZING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
						construct_reqalloc_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
					}
					#ifdef DEBUG
					//printf("Initializing ... \n");
					#endif
					break;
				case ACTIVE_STATE_REALLOCATING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
						// construct_reallocate_packet(mbuf, ctrl->port_id, ctxt);
						construct_getalloc_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
					}
					if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
						construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, 0, 0, NULL, true);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
					}
					break;
				case ACTIVE_STATE_ALLOCATING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
						construct_getalloc_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
					}
					break;
				case ACTIVE_STATE_SNAPSHOTTING:
					snapshotting_in_progress = 1;
					ctxt->allocation.sync_start_time = rte_rdtsc_precise();
					printf("FID %d Snapshotting ... \n", ctxt->program->fid);
					while(snapshotting_in_progress) {
						snapshotting_in_progress = 0;
						for(int i = 0; i < NUM_STAGES; i++) {
							if(!ctxt->allocation.valid_stages[i]) continue;
							for(int j = ctxt->allocation.sync_data[i].mem_start; j <= ctxt->allocation.sync_data[i].mem_end; j++) {
								if(ctxt->allocation.sync_data[i].valid[j]) continue;
								snapshotting_in_progress = 1;
								if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
									construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, i, j, memsync_cache, false);
									rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
									// printf("[SNAPSHOT] stage %d index %d \n", i, j);
								}
							}
						}
					}
					rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
					ctxt->allocation.sync_end_time = rte_rdtsc_precise();
					consume_memory_objects(&ctxt->allocation, ctxt);
					printf("FID %d Snapshot complete.\n", ctxt->program->fid);
					// ctxt->status = ACTIVE_STATE_SNAPCOMPLETING;
					ctxt->status = ACTIVE_STATE_REALLOCATING;
					break;
				case ACTIVE_STATE_SNAPCOMPLETING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
						// construct_snapcomplete_packet(mbuf, ctrl->port_id, ctxt);
						construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, 0, 0, NULL, true);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
						// printf("FID %d sending snapcomplete packet ... \n", ctxt->program->fid);
					}
					break;
				case ACTIVE_STATE_REMAPPING:
					remapping_in_progress = 1;
					memory_t* updated_region = &ctxt->membuf;
					updated_region->fid = ctxt->allocation.fid;
					for(int k = 0; k < NUM_STAGES; k++) {
						updated_region->valid_stages[k] = ctxt->allocation.valid_stages[k];
						updated_region->sync_data[k].mem_start = ctxt->allocation.sync_data[k].mem_start;
						updated_region->sync_data[k].mem_end = ctxt->allocation.sync_data[k].mem_end;
					}
					reset_memory_region(updated_region, ctxt);
					printf("FID %d Resetting ... \n", ctxt->program->fid);
					while(remapping_in_progress) {
						remapping_in_progress = 0;
						for(int i = 0; i < NUM_STAGES; i++) {
							if(!ctxt->allocation.valid_stages[i]) continue;
							for(int j = ctxt->allocation.sync_data[i].mem_start; j <= ctxt->allocation.sync_data[i].mem_end; j++) {
								if(updated_region->sync_data[i].valid[j]) continue;
								snapshotting_in_progress = 1;
								if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
									construct_memremap_packet(mbuf, ctrl->port_id, ctxt, i, j, updated_region->sync_data[i].data[j], memset_cache);
									rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
									// printf("Sending remap for stage %d index %d data %u ... \n", i, j, updated_region->sync_data[i].data[j]);
								}
							}
						}
					}
					rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
					printf("FID %d Reset complete.\n", ctxt->program->fid);
					ctxt->status = ACTIVE_STATE_TRANSMITTING;
					break;
				case ACTIVE_STATE_TRANSMITTING:
					if(elapsed_us < CTRL_HEARTBEAT_ITVL) continue;
					if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
						construct_heartbeat_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
					} else {
						rte_exit(EXIT_FAILURE, "Unable to allocate buffer for control packet.");
					}
					break;
				default:
					break;
			}
		}
	}

	return 0;
}

/*static int
lcore_display(void* arg) {
	while(is_running) {
		update_screen_info();
		rte_delay_us_sleep(1000);
	}
}*/

void 
read_activep4_config(char* config_filename, active_config_t* cfg) {
	FILE* fp = fopen(config_filename, "r");
	char buf[50];
    const char* tok;
	int i, n = 0;
	while( fgets(buf, 50, fp) > 0 ) {
		for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, ",\n"), i++) {
			switch(i) {
				case 0:
					cfg->fid[n] = atoi(tok);
					break;
				case 1:
					strcpy(cfg->appdir[n], tok);
					break;
				case 2:
					strcpy(cfg->appname[n], tok);
					break;
				case 3:
					cfg->num_instances[n] = atoi(tok);
					break;
				case 4:
					cfg->app_id[n] = atoi(tok);
					break;
				default:
					break;
			}
		}
		n++;
	}
	cfg->num_apps = n;
	fclose(fp);
}

/* Cache application specific. */

typedef struct {
	uint64_t	ts_ref;
	uint64_t	last_ts;
	uint64_t	ts[MAX_SAMPLES_CACHE];
	uint32_t	rx_hits[MAX_SAMPLES_CACHE];
	uint32_t	rx_total[MAX_SAMPLES_CACHE];
	uint32_t	num_samples;
	int			stage_id_key;
	int			stage_id_value;
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
	int stage_id_key = cache_ctxt->stage_id_key, stage_id_value = cache_ctxt->stage_id_value;
	uint32_t memsize_keys = alloc->sync_data[stage_id_key].mem_end - alloc->sync_data[stage_id_key].mem_start + 1;
	uint32_t memsize_values = alloc->sync_data[stage_id_value].mem_end - alloc->sync_data[stage_id_value].mem_start + 1;
	int memory_size = (memsize_keys < memsize_values) ? memsize_keys : memsize_values;
	if(memory_size < 2) return;
	// update_addressing_hashtable(alloc, memory_size);
	// struct rte_hash* hash = (struct rte_hash*)alloc->hash_function;
	// uint32_t addr = (uint32_t)rte_hash_add_key(hash, key);
	uint16_t addr = (uint16_t)*key + alloc->sync_data[stage_id_key].mem_start;
	// printf("Key %d addr %d\n", *key, addr);
	ap4data->data[1] = htonl(*key);
	ap4data->data[2] = htonl(addr);
}

void active_rx_handler_cache(activep4_ih* ap4ih, activep4_data_t* ap4args, void* context) {
	if(ap4args == NULL) {
		printf("[ERROR] cache arguments not present!\n");
		return;
	}
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	uint32_t cached_value = ntohl(ap4args->data[0]);
	uint32_t key = ntohl(ap4args->data[1]);
	if(cached_value != 0) cache_ctxt->rx_hits[cache_ctxt->num_samples]++;
	cache_ctxt->rx_total[cache_ctxt->num_samples]++;
	uint64_t now = rte_rdtsc_precise();
	uint64_t elapsed_ms = (double)(now - cache_ctxt->last_ts) * 1E3 / rte_get_tsc_hz();
	if(elapsed_ms >= STATS_ITVL_MS_CACHE && cache_ctxt->num_samples < MAX_SAMPLES_CACHE) {
		// printf("[DEBUG] cache hits %u total %u\n", cache_ctxt->rx_hits[cache_ctxt->num_samples], cache_ctxt->rx_total[cache_ctxt->num_samples]);
		cache_ctxt->last_ts = now;
		cache_ctxt->ts[cache_ctxt->num_samples] = (double)(now - cache_ctxt->ts_ref) * 1E3 / rte_get_tsc_hz();
		cache_ctxt->num_samples++;
	}
	#ifdef DEBUG
	printf("Cache response: flags %x args (%u,%u,%u,%u)\n", ntohs(ap4ih->flags), ntohl(ap4args->data[0]), ntohl(ap4args->data[1]), ntohl(ap4args->data[2]), ntohl(ap4args->data[3]));
	#endif
}

void memory_consume_cache(memory_t* mem, void* context) {}

void memory_reset_cache(memory_t* mem, void* context) {
	cache_context_t* cache_ctxt = (cache_context_t*)context;
	for(int i = 0; i < NUM_STAGES; i++)
		memset(&mem->sync_data[i], 0, MAX_DATA);
	int stage_id_key = cache_ctxt->stage_id_key, stage_id_value = cache_ctxt->stage_id_value;
	if(mem->valid_stages[stage_id_key] && mem->valid_stages[stage_id_value]) {
		uint32_t memsize_keys = mem->sync_data[stage_id_key].mem_end - mem->sync_data[stage_id_key].mem_start + 1;
		uint32_t memsize_values = mem->sync_data[stage_id_value].mem_end - mem->sync_data[stage_id_value].mem_start + 1;
		uint32_t memsize = (memsize_keys < memsize_values) ? memsize_keys : memsize_values;
		printf("[INFO] remapping %d memory objects in stages (%d,%d) from base address %u.\n", memsize, stage_id_key, stage_id_value, mem->sync_data[stage_id_key].mem_start);
		for(int i = 0; i < memsize; i++) {
			uint16_t addr = (uint16_t)i + mem->sync_data[stage_id_key].mem_start;
			mem->sync_data[stage_id_key].data[addr] = i;
			mem->sync_data[stage_id_value].data[addr] = i;
		}
	}
}

int
main(int argc, char** argv)
{
	if(argc < 3) {
		printf("Usage: %s <iface> <config_file>\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	// initialize_display();

	is_running = 1;
	signal(SIGINT, interrupt_handler);

	char* dev = argv[1];
	char* config_filename = argv[2];

	int ret = rte_eal_init(argc, argv);

	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

	active_config_t cfg;
	memset(&cfg, 0, sizeof(active_config_t));
	read_activep4_config(config_filename, &cfg);

	if(cfg.num_apps > MAX_APPS) cfg.num_apps = MAX_APPS;

	printf("Read configurations for %d apps.\n", cfg.num_apps);

	int sockfd = 0;
	if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(EXIT_FAILURE);
    }
	uint32_t ipv4_ifaceaddr = 0;
	size_t if_name_len = strlen(dev);
	struct ifreq ifr;
	if(if_name_len < sizeof(ifr.ifr_name)) {
        memcpy(ifr.ifr_name, dev, if_name_len);
        ifr.ifr_name[if_name_len] = 0;
    } else {
        fprintf(stderr, "Interface name is too long!\n");
        exit(1);
    }
	ifr.ifr_addr.sa_family = AF_INET;
    if(ioctl(sockfd, SIOCGIFADDR, &ifr) < 0) {
        perror("ioctl");
        exit(1);
    }
    memcpy(&ipv4_ifaceaddr, &((struct sockaddr_in*)&ifr.ifr_addr)->sin_addr.s_addr, sizeof(uint32_t));

	char ip_addr_str[16];
	inet_ntop(AF_INET, &ipv4_ifaceaddr, ip_addr_str, 16);
	printf("Interface %s has IPv4 address %s\n", dev, ip_addr_str);

	pnemonic_opcode_t instr_set;
	memset(&instr_set, 0, sizeof(pnemonic_opcode_t));

	activep4_def_t* active_function = (activep4_def_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(activep4_def_t), 0);
	if(active_function == NULL) {
		printf("Unable to allocate memory for active function!\n");
		exit(EXIT_FAILURE);
	}

	activep4_context_t* ap4_ctxt = (activep4_context_t*)rte_zmalloc(NULL, MAX_APPS * MAX_INSTANCES * sizeof(activep4_context_t), 0);
	if(ap4_ctxt == NULL) {
		printf("Unable to allocate memory for active context!\n");
		exit(EXIT_FAILURE);
	}

	cache_context_t* cache_ctxt = (cache_context_t*)rte_zmalloc(NULL, MAX_APPS * MAX_INSTANCES * sizeof(cache_context_t), 0);
	if(cache_ctxt == NULL) {
		printf("Unable to allocate memory for cache context!\n");
		exit(EXIT_FAILURE);
	}

	active_apps_t apps_ctxt;
	memset(&apps_ctxt, 0, sizeof(active_apps_t));

	int inst_id = 0;
	for(int i = 0; i < cfg.num_apps; i++) {
		char* active_dir = cfg.appdir[i];
		char* active_program_name = cfg.appname[i];
		int fid = cfg.fid[i];
		read_opcode_action_map(INSTR_SET_PATH, &instr_set);
		read_active_function(&active_function[i], active_dir, active_program_name);
		for(int j = 0; j < cfg.num_instances[i]; j++) {
			cache_ctxt[inst_id].stage_id_key = 2;
			cache_ctxt[inst_id].stage_id_value = 5;
			cache_ctxt[inst_id].ts_ref = rte_rdtsc_precise();
			ap4_ctxt[inst_id].instr_set = &instr_set;
			ap4_ctxt[inst_id].program = rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
			assert(ap4_ctxt[inst_id].program != NULL);
			rte_memcpy(ap4_ctxt[inst_id].program, &active_function[i], sizeof(activep4_def_t));
			ap4_ctxt[inst_id].program->fid = fid + j;
			ap4_ctxt[inst_id].is_active = false;
			ap4_ctxt[inst_id].status = ACTIVE_STATE_INITIALIZING;
			// ap4_ctxt[inst_id].allocation.valid_stages[2] = 1;
			// ap4_ctxt[inst_id].allocation.sync_data[2].mem_start = 0;
			// ap4_ctxt[inst_id].allocation.sync_data[2].mem_end = 65535;
			// ap4_ctxt[inst_id].allocation.valid_stages[5] = 1;
			// ap4_ctxt[inst_id].allocation.sync_data[5].mem_start = 0;
			// ap4_ctxt[inst_id].allocation.sync_data[5].mem_end = 65535;
			// ap4_ctxt[inst_id].status = ACTIVE_STATE_REMAPPING;
			// ap4_ctxt[inst_id].status = ACTIVE_STATE_TRANSMITTING;
			ap4_ctxt[inst_id].ipv4_srcaddr = ipv4_ifaceaddr;
			ap4_ctxt[inst_id].app_context = &cache_ctxt[inst_id];
			ap4_ctxt[inst_id].payload_parser = payload_parser_cache;
			ap4_ctxt[inst_id].rx_handler = active_rx_handler_cache;
			ap4_ctxt[inst_id].memory_consume = memory_consume_cache;
			ap4_ctxt[inst_id].memory_reset = memory_reset_cache;
			ap4_ctxt[inst_id].shutdown = shutdown_cache;
			apps_ctxt.app_id[inst_id] = cfg.app_id[i];
			printf("ActiveP4 context initialized for %s instance %d.\n", active_program_name, j);
			inst_id++;
		}
	}

	apps_ctxt.ctxt = ap4_ctxt;
	apps_ctxt.num_apps_instances = inst_id;

	struct rte_mempool *mbuf_pool;
	uint16_t nb_ports;
	uint16_t portid;

	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports > 1)
		rte_exit(EXIT_FAILURE, "Error: at most one port is required.\n");

	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL",
		NUM_MBUFS * nb_ports, MBUF_CACHE_SIZE, 0,
		RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	buffer = rte_zmalloc(NULL, RTE_ETH_TX_BUFFER_SIZE(BURST_SIZE), 0);
	if(buffer == NULL)
		rte_exit(EXIT_FAILURE, "Cannot allocate TX buffer for control thread.");
	if(rte_eth_tx_buffer_init(buffer, BURST_SIZE) != 0)
		rte_exit(EXIT_FAILURE, "Cannot initialize TX buffer for control thread.");
	if(rte_eth_tx_buffer_set_err_callback(buffer, rte_eth_tx_buffer_count_callback, &drop_counter) < 0)
		rte_exit(EXIT_FAILURE, "Cannot set error callback for TX buffer for control thread.");

	active_control_t ctrl;
	memset(&ctrl, 0, sizeof(active_control_t));
	ctrl.apps_ctxt = &apps_ctxt;
	ctrl.mempool = mbuf_pool;

	unsigned port_count = 0;
	RTE_ETH_FOREACH_DEV(portid) {
		struct rte_ether_addr addr = {0};
		char portname[32];
		char portargs[256];
		if(++port_count > nb_ports)
			break;
		rte_eth_macaddr_get(portid, &addr);
		snprintf(portname, sizeof(portname), "virtio_user%u", portid);
		snprintf(
			portargs, 
			sizeof(portargs),
			"path=/dev/vhost-net,queues=1,queue_size=%u,iface=%s,mac=" RTE_ETHER_ADDR_PRT_FMT,
			RX_RING_SIZE, portname, 
			RTE_ETHER_ADDR_BYTES(&addr)
		);
		if(rte_eal_hotplug_add("vdev", portname, portargs) < 0)
			rte_exit(EXIT_FAILURE, "Cannot create paired port for port %u\n", portid);
		printf("Created virtual port %s\n", portname);
		ctrl.port_id = portid;
	}

	unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);

	int ports[RTE_MAX_ETHPORTS];
	RTE_ETH_FOREACH_DEV(portid) {
		ports[portid] = portid;
		if(port_init(portid, mbuf_pool, &apps_ctxt) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);
		rte_eal_remote_launch(lcore_stats, (void*)&ports[portid], lcore_id);
		lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	}

	rte_eal_remote_launch(lcore_control, (void*)&ctrl, lcore_id);
	lcore_id = rte_get_next_lcore(lcore_id, 1, 0);

	#ifdef PDUMP_ENABLE
	if(rte_pdump_init() < 0) {
		rte_exit(EXIT_FAILURE, "Unable to initialize packet capture.");
	}
	#endif

	// rte_eal_remote_launch(lcore_display, NULL, lcore_id);
	// lcore_id = rte_get_next_lcore(lcore_id, 1, 0);

	lcore_main();

	for(int i = 0; i < apps_ctxt.num_apps_instances; i++) {
		apps_ctxt.ctxt[i].shutdown(i, apps_ctxt.ctxt[i].app_context);
	}

	rte_eal_cleanup();
	// endwin();

	return 0;
}
