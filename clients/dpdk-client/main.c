/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright(c) 2010-2015 Intel Corporation
 */

#define DEBUG

#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <inttypes.h>
#include <getopt.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_mbuf_dyn.h>
#include <rte_compat.h>
#include <rte_memory.h>
#include <rte_malloc.h>

#include "../../headers/activep4.h"
#include "./include/types.h"
#include "./include/utils.h"

#define INSTR_SET_PATH		"opcode_action_mapping.csv"

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

	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++)
		ap4data->data[i] = ap4_ctxt->data.data[i];

	for(int i = 0; i < ap4_ctxt->program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = ap4_ctxt->program->code[i].opcode;
	}

	pkt->pkt_len += ap4hlen;
	pkt->data_len += ap4hlen;
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
	activep4_context_t* ap4_ctxt = (activep4_context_t*)ctxt;

	for(int i = 0; i < nb_pkts; i++) {
		switch(ap4_ctxt->status) {
			case ACTIVE_STATE_TRANSMITTING:
				// TODO update program data.
				insert_active_program_headers(ap4_ctxt, pkts[i]);
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
	activep4_context_t* ap4_ctxt = (activep4_context_t*)ctxt;

	for(int k = 0; k < nb_pkts; k++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[k], char*);
		struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
		int offset = 0;
		if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
			hdr_eth->ether_type = htons(RTE_ETHER_TYPE_IPV4);
			activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
			if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
			uint16_t flags = ntohs(ap4ih->flags);
			offset += sizeof(activep4_ih);
			if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
				offset += sizeof(activep4_data_t);
			}
			if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
				offset += sizeof(activep4_malloc_res_t);
			}
			if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_EOE)) {
				offset += get_active_eof(bufptr + sizeof(struct rte_ether_hdr) + offset, pkts[k]->pkt_len);
			}
			for(int i = 0; i < pkts[k]->pkt_len - sizeof(struct rte_ether_hdr) - offset; i++) {
				bufptr[sizeof(struct rte_ether_hdr) + i] = bufptr[sizeof(struct rte_ether_hdr) + offset + i];
			}
			pkts[k]->pkt_len -= offset;
			pkts[k]->data_len -= offset;
		}
		// TODO add context for active programs.
	}	

	return nb_pkts;
}

static uint16_t
active_eth_rx_hook(
	uint16_t port_id, 
	uint16_t queue, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	uint16_t max_pkts, 
	void *ctxt
) {
	activep4_context_t* ap4_ctxt = (activep4_context_t*)ctxt;

	for(int k = 0; k < nb_pkts; k++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[k], char*);
		struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
		if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
			activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
			if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
			uint16_t flags = ntohs(ap4ih->flags);
			if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REQALLOC)) {
				// ack for reqalloc.
				ap4_ctxt->status = ACTIVE_STATE_ALLOCATING;
			} else if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
				// TODO test.
				if(ap4_ctxt->allocation.version != ntohs(ap4ih->seq)) {
					activep4_malloc_res_t* ap4malloc = (activep4_malloc_res_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
					for(int i = 0; i < NUM_STAGES; i++) {
						ap4_ctxt->allocation.sync_data[i].mem_start = ntohs(ap4malloc->mem_range[i].start);
						ap4_ctxt->allocation.sync_data[i].mem_end = ntohs(ap4malloc->mem_range[i].end);
						if((ap4_ctxt->allocation.sync_data[i].mem_end - ap4_ctxt->allocation.sync_data[i].mem_start) > 0) {
							ap4_ctxt->allocation.valid_stages[i] = 1;
							#ifdef DEBUG
							printf("[ALLOCATION][%d] %d - %d\n", i, ap4_ctxt->allocation.sync_data[i].mem_start, ap4_ctxt->allocation.sync_data[i].mem_end);
							#endif
						}
					}
					ap4_ctxt->allocation.version = ntohs(ap4ih->seq);
				}
				ap4_ctxt->status = ACTIVE_STATE_TRANSMITTING;
				#ifdef DEBUG
				printf("Allocated. Transmitting ... \n");
				#endif
			} else if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REMAPPED)) {
				// TODO test.
				if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ACK)) {
					ap4_ctxt->status = ACTIVE_STATE_TRANSMITTING;
				} else if(ap4_ctxt->allocation.version == ntohs(ap4ih->seq) && ap4_ctxt->status != ACTIVE_STATE_SNAPSHOTTING) {
					ap4_ctxt->allocation.sync_version = ntohs(ap4ih->seq);
					for(int i = 0; i < NUM_STAGES; i++) {
						for(int j = 0; j < MAX_DATA; j++) {
							ap4_ctxt->allocation.sync_data[i].valid[j] = 0;
						}
					}
					ap4_ctxt->allocation.invalid = 1;
					ap4_ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
				}
			} else if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_INITIATED) && ap4_ctxt->status == ACTIVE_STATE_SNAPSHOTTING) {
				// TODO test.
				if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
					activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
					int mem_addr = ntohl(ap4data->data[0]);
					int mem_data = ntohl(ap4data->data[1]);
					int stage_id = ntohl(ap4data->data[2]);
					ap4_ctxt->allocation.sync_data[stage_id].data[mem_addr] = mem_data;
					ap4_ctxt->allocation.sync_data[stage_id].valid[mem_addr] = 1;
				}
			}
		}
	}
	return nb_pkts;
}

static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool, activep4_context_t* ctxt)
{
	struct rte_eth_conf port_conf;
	const uint16_t rx_rings = 1, tx_rings = 1;
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

	if (dev_info.tx_offload_capa & RTE_ETH_TX_OFFLOAD_MBUF_FAST_FREE)
		port_conf.txmode.offloads |=
			RTE_ETH_TX_OFFLOAD_MBUF_FAST_FREE;

	/*if (hw_timestamping) {
		if (!(dev_info.rx_offload_capa & RTE_ETH_RX_OFFLOAD_TIMESTAMP)) {
			printf("\nERROR: Port %u does not support hardware timestamping\n"
					, port);
			return -1;
		}
		port_conf.rxmode.offloads |= RTE_ETH_RX_OFFLOAD_TIMESTAMP;
		rte_mbuf_dyn_rx_timestamp_register(&hwts_dynfield_offset, NULL);
		if (hwts_dynfield_offset < 0) {
			printf("ERROR: Failed to register timestamp field\n");
			return -rte_errno;
		}
	}*/

	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0)
		return retval;

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
		return retval;

	rxconf = dev_info.default_rxconf;

	for (q = 0; q < rx_rings; q++) {
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

	/*if (hw_timestamping && ticks_per_cycle_mult  == 0) {
		uint64_t cycles_base = rte_rdtsc();
		uint64_t ticks_base;
		retval = rte_eth_read_clock(port, &ticks_base);
		if (retval != 0)
			return retval;
		rte_delay_ms(100);
		uint64_t cycles = rte_rdtsc();
		uint64_t ticks;
		rte_eth_read_clock(port, &ticks);
		uint64_t c_freq = cycles - cycles_base;
		uint64_t t_freq = ticks - ticks_base;
		double freq_mult = (double)c_freq / t_freq;
		printf("TSC Freq ~= %" PRIu64
				"\nHW Freq ~= %" PRIu64
				"\nRatio : %f\n",
				c_freq * 10, t_freq * 10, freq_mult);
		ticks_per_cycle_mult = (1 << TICKS_PER_CYCLE_SHIFT) / freq_mult;
	}*/

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

	if(is_virtual_dev) {
		//rte_eth_add_tx_callback(port, 0, active_decap_filter, (void*)ctxt);
		//rte_eth_add_rx_callback(port, 0, active_encap_filter, (void*)ctxt);
	} else {
		//rte_eth_add_rx_callback(port, 0, active_eth_rx_hook, (void*)ctxt);
	}

	return 0;
}

static  __rte_noreturn void
lcore_main(active_control_t* ctrl, int num_apps)
{
	uint16_t port;

	uint8_t vdev[MAX_APPS + 1];
	memset(vdev, 0, MAX_APPS + 1);

	RTE_ETH_FOREACH_DEV(port) {
		struct rte_eth_dev_info dev_info;
		if(rte_eth_dev_info_get(port, &dev_info) != 0) {
			printf("Error during getting device (port %u)\n", port);
			exit(EXIT_FAILURE);
		}
		if(strcmp(dev_info.driver_name, "net_virtio_user") == 0) {
			vdev[port] = 1;
		}
		if(rte_eth_dev_socket_id(port) > 0 && rte_eth_dev_socket_id(port) != (int)rte_socket_id())
			printf("WARNING, port %u is on remote NUMA node to "
					"polling thread.\n\tPerformance will "
					"not be optimal.\n", port);
		else
			printf("Port %d on local NUMA node.\n", port);
	}

	printf("\nCore %u forwarding packets. [Ctrl+C to quit]\n", rte_lcore_id());

	struct rte_eth_dev_tx_buffer* buffer = (struct rte_eth_dev_tx_buffer*)rte_zmalloc(NULL, MAX_APPS * sizeof(struct rte_eth_dev_tx_buffer), RTE_CACHE_LINE_SIZE);
	if(buffer == NULL) {
		printf("Failed to allocate buffer!\n");
		exit(EXIT_FAILURE);
	}
	for(int i = 0; i < num_apps; i++) {
		if(rte_eth_tx_buffer_init(&buffer[i], BURST_SIZE) != 0) {
			printf("Unable to initialize buffer!\n");
			exit(EXIT_FAILURE);
		}
	}

	for(;;) {
		RTE_ETH_FOREACH_DEV(port) {
			struct rte_mbuf *bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(port, 0, bufs, BURST_SIZE);
			
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

			// Perform bridging virtio-phyeth.
			if(vdev[port]) {
				nb_tx = rte_eth_tx_burst(PORT_PETH, 0, bufs, nb_rx);
				if(unlikely(nb_tx < nb_rx)) {
					uint16_t buf;
					for(buf = nb_tx; buf < nb_rx; buf++)
						rte_pktmbuf_free(bufs[buf]);
				}
				#ifdef DEBUG
				printf("[PORT %d][TX] %d pkts.\n", PORT_PETH, nb_tx);
				#endif
			} else {
				for(int i = 0; i < nb_rx; i++) {
					char* bufptr = rte_pktmbuf_mtod(bufs[i], char*);
					struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
					if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
						activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
						if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue; 
						int fid = ntohs(ap4ih->fid);
						for(int j = 0; j < num_apps; j++) {
							if(ctrl[j].ctxt->program->fid == fid) {
								rte_eth_tx_buffer(ctrl[j].port_id, 0, &buffer[j], bufs[i]);
								#ifdef DEBUG
								printf("[PORT %d][TX] %d pkts.\n", ctrl[j].port_id, 1);
								#endif
							}
						}
					} else if(ntohs(hdr_eth->ether_type) == RTE_ETHER_TYPE_IPV4) {
						struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr));
						int net_id = (iph->dst_addr & 0x0000FF00) >> 8;
						rte_eth_tx_buffer(ctrl[net_id - 1].port_id, 0, &buffer[net_id - 1], bufs[i]);
						#ifdef DEBUG
						printf("[PORT %d][TX] %d pkts.\n", ctrl[net_id - 1].port_id, 1);
						#endif
					}
				}
				for(int i = 0; i < num_apps; i++) {
					rte_eth_tx_buffer_flush(ctrl[i].port_id, 0, &buffer[i]);
				}
			}
		}
	}
}

static int
lcore_stats(void* arg) {
	
	unsigned lcore_id = rte_lcore_id();

	int port_id = *((int*)arg);

	uint64_t last_ipackets = 0, last_opackets = 0;
	
	printf("Starting stats monitor for port %d on lcore %u ... \n", port_id, lcore_id);

	while(TRUE) {
		struct rte_eth_stats stats = {0};
		if(rte_eth_stats_get(port_id, &stats) == 0) {
			uint64_t rx_pkts = stats.ipackets - last_ipackets;
			uint64_t tx_pkts = stats.opackets - last_opackets;
			last_ipackets = stats.ipackets;
			last_opackets = stats.opackets;
			#ifdef DEBUG
			if(rx_pkts > 0 || tx_pkts > 0)
				printf("[STATS][%d] RX %lu pkts TX %lu pkts\n", port_id, rx_pkts, tx_pkts);
			#endif
		}
		rte_delay_us_block(DELAY_SEC);
	}
	
	return 0;
}

static inline void construct_reqalloc_packet(struct rte_mbuf* mbuf, active_control_t* ctrl) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(ctrl->port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_REQALLOC);
	ap4ih->fid = htons(ctrl->ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_malloc_req_t* mreq = (activep4_malloc_req_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	mreq->proglen = htons((uint16_t)ctrl->ctxt->program->proglen);
	mreq->iglim = (uint8_t)ctrl->ctxt->program->iglim;
	for(int i = 0; i < ctrl->ctxt->program->num_accesses; i++) {
		mreq->mem[i] = ctrl->ctxt->program->access_idx[i];
		mreq->dem[i] = ctrl->ctxt->program->demand[i];
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
	iph->src_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->dst_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_getalloc_packet(struct rte_mbuf* mbuf, active_control_t* ctrl) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(ctrl->port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr)); 
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_GETALLOC);
	ap4ih->fid = htons(ctrl->ctxt->program->fid);
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
	iph->src_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->dst_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_snapshot_packet(struct rte_mbuf* mbuf, active_control_t* ctrl, int stage_id, int mem_addr, activep4_def_t* memsync_cache) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(ctrl->port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_INITIATED);
	ap4ih->fid = htons(ctrl->ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	ap4data->data[0] = htonl((uint32_t)mem_addr);
	ap4data->data[2] = htonl((uint32_t)stage_id);
	activep4_def_t* program = construct_memsync_program(ctrl->ctxt->program->fid, stage_id, ctrl->ctxt->instr_set, memsync_cache);
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
	iph->src_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->dst_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_snapcomplete_packet(struct rte_mbuf* mbuf, active_control_t* ctrl) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(ctrl->port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr)); 
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_ACK);
	ap4ih->fid = htons(ctrl->ctxt->program->fid);
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
	iph->src_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->dst_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static inline void construct_heartbeat_packet(struct rte_mbuf* mbuf, active_control_t* ctrl) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(ctrl->port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_INITIATED);
	ap4ih->fid = htons(ctrl->ctxt->program->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t program = {0};
	construct_nop_program(&program, ctrl->ctxt->instr_set, 0);
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
	iph->src_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->dst_addr = ctrl->ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program.proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static int
lcore_control(void* arg) {

	unsigned lcore_id = rte_lcore_id();

	active_control_t* ctrl = (active_control_t*)arg;

	printf("Starting controller for port %d on lcore %u ... \n", PORT_PETH, lcore_id);

	struct rte_mbuf* mbuf;

	struct rte_eth_dev_tx_buffer buffer;
	if(rte_eth_tx_buffer_init(&buffer, BURST_SIZE) != 0) {
		printf("Unable to initialize buffer!\n");
		return -1;
	}

	activep4_def_t memsync_cache[NUM_STAGES];
	memset(memsync_cache, 0, NUM_STAGES * sizeof(activep4_def_t));

	uint64_t last_sent = 0, now, elapsed_us;
	int snapshotting_in_progress = 0;

	while(TRUE) {
		now = rte_rdtsc_precise();
		elapsed_us = (double)(now - last_sent) * 1E6 / rte_get_tsc_hz();
		switch(ctrl->ctxt->status) {
			case ACTIVE_STATE_INITIALIZING:
				if(elapsed_us < CTRL_SEND_INTVL_US) continue;
				if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
					construct_reqalloc_packet(mbuf, ctrl);
					rte_eth_tx_buffer(PORT_PETH, 0, &buffer, mbuf);
					rte_eth_tx_buffer_flush(PORT_PETH, 0, &buffer);
					last_sent = now;
				}
				#ifdef DEBUG
				//printf("Initializing ... \n");
				#endif
				break;
			case ACTIVE_STATE_ALLOCATING:
				if(elapsed_us < CTRL_SEND_INTVL_US) continue;
				if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
					construct_getalloc_packet(mbuf, ctrl);
					rte_eth_tx_buffer(PORT_PETH, 0, &buffer, mbuf);
					rte_eth_tx_buffer_flush(PORT_PETH, 0, &buffer);
					last_sent = now;
				}
				break;
			case ACTIVE_STATE_SNAPSHOTTING:
				snapshotting_in_progress = 1;
				ctrl->ctxt->allocation.sync_start_time = rte_rdtsc_precise();
				while(snapshotting_in_progress) {
					snapshotting_in_progress = 0;
					for(int i = 0; i < NUM_STAGES; i++) {
						if(!ctrl->ctxt->allocation.valid_stages[i]) continue;
						for(int j = ctrl->ctxt->allocation.sync_data[i].mem_start; j <= ctrl->ctxt->allocation.sync_data[i].mem_end; j++) {
							if(ctrl->ctxt->allocation.sync_data[i].valid[j]) continue;
							snapshotting_in_progress = 1;
							if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
								construct_snapshot_packet(mbuf, ctrl, i, j, memsync_cache);
								rte_eth_tx_buffer(PORT_PETH, 0, &buffer, mbuf);
							}
						}
					}
				}
				rte_eth_tx_buffer_flush(PORT_PETH, 0, &buffer);
				ctrl->ctxt->allocation.sync_end_time = rte_rdtsc_precise();
				ctrl->ctxt->status = ACTIVE_STATE_SNAPCOMPLETING;
				break;
			case ACTIVE_STATE_SNAPCOMPLETING:
				if(elapsed_us < CTRL_SEND_INTVL_US) continue;
				if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
					construct_snapcomplete_packet(mbuf, ctrl);
					rte_eth_tx_buffer(PORT_PETH, 0, &buffer, mbuf);
					rte_eth_tx_buffer_flush(PORT_PETH, 0, &buffer);
					last_sent = now;
				}
				break;
			case ACTIVE_STATE_TRANSMITTING:
				if(elapsed_us < CTRL_HEARTBEAT_ITVL) continue;
				if((mbuf = rte_pktmbuf_alloc(ctrl->mempool)) != NULL) {
					construct_heartbeat_packet(mbuf, ctrl);
					rte_eth_tx_buffer(PORT_PETH, 0, &buffer, mbuf);
					rte_eth_tx_buffer_flush(PORT_PETH, 0, &buffer);
					last_sent = now;
				}
				break;
			default:
				break;
		}
	}

	return 0;
}

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
				default:
					break;
			}
		}
		n++;
	}
	cfg->num_apps = n;
	fclose(fp);
}

int
main(int argc, char** argv)
{
	if(argc < 3) {
		printf("Usage: %s <iface> <config_file>\n", argv[0]);
		exit(EXIT_FAILURE);
	}

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

	activep4_def_t* active_function = (activep4_def_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(activep4_def_t), RTE_CACHE_LINE_SIZE);
	if(active_function == NULL) {
		printf("Unable to allocate memory for active function!\n");
		exit(EXIT_FAILURE);
	}

	activep4_context_t* ap4_ctxt = (activep4_context_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(activep4_context_t), RTE_CACHE_LINE_SIZE);
	if(ap4_ctxt == NULL) {
		printf("Unable to allocate memory for active context!\n");
		exit(EXIT_FAILURE);
	}

	for(int i = 0; i < cfg.num_apps; i++) {
		char* active_dir = cfg.appdir[i];
		char* active_program_name = cfg.appname[i];
		int fid = cfg.fid[i];
		read_opcode_action_map(INSTR_SET_PATH, &instr_set);
		read_active_function(&active_function[i], active_dir, active_program_name);
		// TODO data argument definitions.
		active_function[i].fid = fid;
		ap4_ctxt[i].instr_set = &instr_set;
		ap4_ctxt[i].program = &active_function[i];
		ap4_ctxt[i].is_active = 1;
		ap4_ctxt[i].status = ACTIVE_STATE_INITIALIZING;
		ap4_ctxt[i].ipv4_srcaddr = ipv4_ifaceaddr;
		printf("ActiveP4 context initialized for %s.\n", active_program_name);
	}

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

	unsigned port_count = 0;
	struct rte_ether_addr addr = {0};
	RTE_ETH_FOREACH_DEV(portid) {
		if(++port_count > nb_ports)
			break;
		rte_eth_macaddr_get(portid, &addr);
	}

	active_control_t* ctrl = (active_control_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(active_control_t), RTE_CACHE_LINE_SIZE);
	if(ctrl == NULL) {
		printf("Unable to allocate memory for active control!\n");
		exit(EXIT_FAILURE);
	}

	unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);

	for(int i = 0; i < cfg.num_apps; i++) {
		portid = i + 1;
		char portname[32];
		char portargs[256];
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
	}

	RTE_ETH_FOREACH_DEV(portid) {
		int port_id = portid;
		if(port_id == 0) {
			if(port_init(portid, mbuf_pool, NULL) != 0)
				rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);
		} else {
			if(port_init(portid, mbuf_pool, &ap4_ctxt[port_count - 1]) != 0)
				rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);
		}
		rte_eal_remote_launch(lcore_stats, (void*)&port_id, lcore_id);
		lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	}

	for(int i = 0; i < cfg.num_apps; i++) {
		portid = i + 1;
		ctrl[i].port_id = portid;
		ctrl[i].ctxt = &ap4_ctxt[i];
		ctrl[i].mempool = mbuf_pool;
		/*rte_eal_remote_launch(lcore_control, (void*)&ctrl[i], lcore_id);
		lcore_id = rte_get_next_lcore(lcore_id, 1, 0);*/
	}

	lcore_main(ctrl, cfg.num_apps);

	rte_eal_cleanup();

	return 0;
}
