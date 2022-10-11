/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright(c) 2010-2015 Intel Corporation
 */

#define DEBUG

#include <stdint.h>
#include <inttypes.h>
#include <getopt.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_mbuf_dyn.h>

#include "../../headers/activep4.h"

#define TEST_FLAG(x, y)		((x & y) > 0)

#define RX_RING_SIZE 		1024
#define TX_RING_SIZE 		1024

#define NUM_MBUFS 			8191
#define MBUF_CACHE_SIZE 	250
#define BURST_SIZE			32

#define AP4_ETHER_TYPE_AP4	0x83B2

#define INSTR_SET_PATH		"../../config/opcode_action_mapping.csv"

/*static int hwts_dynfield_offset = -1;

static inline rte_mbuf_timestamp_t *
hwts_field(struct rte_mbuf *mbuf)
{
	return RTE_MBUF_DYNFIELD(mbuf, hwts_dynfield_offset, rte_mbuf_timestamp_t *);
}

typedef uint64_t tsc_t;
static int tsc_dynfield_offset = -1;

static inline tsc_t *
tsc_field(struct rte_mbuf *mbuf)
{
	return RTE_MBUF_DYNFIELD(mbuf, tsc_dynfield_offset, tsc_t *);
}*/

static const char usage[] =
	"%s EAL_ARGS -- [-t]\n";

/*static struct {
	uint64_t total_cycles;
	uint64_t total_queue_cycles;
	uint64_t total_pkts;
} latency_numbers;

int hw_timestamping;

#define TICKS_PER_CYCLE_SHIFT 16
static uint64_t ticks_per_cycle_mult;*/

/*static uint16_t
add_timestamps(
	uint16_t port __rte_unused, 
	uint16_t qidx __rte_unused,
	struct rte_mbuf **pkts, 
	uint16_t nb_pkts,
	uint16_t max_pkts __rte_unused, 
	void *_ __rte_unused
) {
	unsigned i;
	uint64_t now = rte_rdtsc();
	for(i = 0; i < nb_pkts; i++)
		*tsc_field(pkts[i]) = now;
	return nb_pkts;
}*/

/*static uint16_t
calc_latency(
	uint16_t port, 
	uint16_t qidx __rte_unused,
	struct rte_mbuf **pkts, 
	uint16_t nb_pkts, 
	void *_ __rte_unused
) {
	uint64_t cycles = 0;
	uint64_t queue_ticks = 0;
	uint64_t now = rte_rdtsc();
	uint64_t ticks;
	unsigned i;

	if (hw_timestamping)
		rte_eth_read_clock(port, &ticks);

	for (i = 0; i < nb_pkts; i++) {
		cycles += now - *tsc_field(pkts[i]);
		if (hw_timestamping)
			queue_ticks += ticks - *hwts_field(pkts[i]);
	}

	latency_numbers.total_cycles += cycles;
	if (hw_timestamping)
		latency_numbers.total_queue_cycles += (queue_ticks
			* ticks_per_cycle_mult) >> TICKS_PER_CYCLE_SHIFT;

	latency_numbers.total_pkts += nb_pkts;

	if (latency_numbers.total_pkts > (100 * 1000 * 1000ULL)) {
		printf("Latency = %"PRIu64" cycles\n",
		latency_numbers.total_cycles / latency_numbers.total_pkts);
		if (hw_timestamping) {
			printf("Latency from HW = %"PRIu64" cycles\n",
			   latency_numbers.total_queue_cycles
			   / latency_numbers.total_pkts);
		}
		latency_numbers.total_cycles = 0;
		latency_numbers.total_queue_cycles = 0;
		latency_numbers.total_pkts = 0;
	}
	return nb_pkts;
}*/

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
	void *ctxt
) {
	activep4_context_t* ap4_ctxt = (activep4_context_t*)ctxt;

	for(int i = 0; i < nb_pkts; i++) {
		switch(ap4_ctxt->status) {
			case ACTIVE_STATE_TRANSMITTING:
				// TODO update program data.
				insert_active_program_headers(ap4_ctxt, pkts[i]);
				break;
			case ACTIVE_STATE_ALLOCATING:
				// TODO implement. 
				break;
			default:
				break;
		}
	}

	return nb_pkts;
}

static inline void strip_active_headers(activep4_context_t* ap4_ctxt, struct rte_mbuf* pkt) {}

static uint16_t
active_decap_filter(
	uint16_t port_id __rte_unused, 
	uint16_t queue __rte_unused, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	void *ctxt
) {
	activep4_context_t* ap4_ctxt = (activep4_context_t*)ctxt;

	for(int i = 0; i < nb_pkts; i++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[i], char*);
		struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
		int offset = 0;
		if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
			activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
			hdr_eth->ether_type = htons(RTE_ETHER_TYPE_IPV4);
			if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
			uint16_t flags = ntohs(ap4ih->flags);
			offset += sizeof(activep4_ih);
			// TODO process active data.
			if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
				offset += sizeof(activep4_data_t);
			}
			if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
				offset += sizeof(activep4_malloc_res_t);
			}
			if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_EOE)) {
				offset += get_active_eof(bufptr + sizeof(struct rte_ether_hdr) + offset, pkts[i]->pkt_len);
			}
			for(int i = 0; i < offset; i++) {
				bufptr[sizeof(struct rte_ether_hdr) + i] = bufptr[sizeof(struct rte_ether_hdr) + offset + i];
			}
			pkts[i]->pkt_len -= offset;
			pkts[i]->data_len -= offset;
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
		printf("Error during getting device (port %u) info: %s\n",
				port, strerror(-retval));

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
		retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
			rte_eth_dev_socket_id(port), &rxconf, mbuf_pool);
		if (retval < 0)
			return retval;
	}

	txconf = dev_info.default_txconf;
	txconf.offloads = port_conf.txmode.offloads;
	for (q = 0; q < tx_rings; q++) {
		retval = rte_eth_tx_queue_setup(port, q, nb_txd,
				rte_eth_dev_socket_id(port), &txconf);
		if (retval < 0)
			return retval;
	}

	retval  = rte_eth_dev_start(port);
	if (retval < 0)
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
		printf("Failed to get MAC address on port %u: %s\n",
			port, rte_strerror(-retval));
		return retval;
	}
	printf("Port %u MAC: %02"PRIx8" %02"PRIx8" %02"PRIx8
			" %02"PRIx8" %02"PRIx8" %02"PRIx8"\n",
			(unsigned)port,
			RTE_ETHER_ADDR_BYTES(&addr));

	retval = rte_eth_promiscuous_enable(port);
	if(retval != 0 && port % 2 == 0) return retval;

	if(ctxt->is_active) {
		if(port % 2 == 0)
			rte_eth_add_tx_callback(port, 0, active_encap_filter, (void*)ctxt);
		else
			rte_eth_add_tx_callback(port, 0, active_decap_filter, (void*)ctxt);
	}

	//rte_eth_add_rx_callback(port, 0, add_timestamps, NULL);
	//rte_eth_add_tx_callback(port, 0, calc_latency, NULL);

	return 0;
}

static  __rte_noreturn void
lcore_main(void)
{
	uint16_t port;

	RTE_ETH_FOREACH_DEV(port)
		if (rte_eth_dev_socket_id(port) > 0 &&
				rte_eth_dev_socket_id(port) !=
						(int)rte_socket_id())
			printf("WARNING, port %u is on remote NUMA node to "
					"polling thread.\n\tPerformance will "
					"not be optimal.\n", port);
		else
			printf("Port %d on local NUMA node.\n", port);

	printf("\nCore %u forwarding packets. [Ctrl+C to quit]\n", rte_lcore_id());

	for(;;) {
		RTE_ETH_FOREACH_DEV(port) {
			struct rte_mbuf *bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(port, 0, bufs, BURST_SIZE);
			
			if (unlikely(nb_rx == 0))
				continue;

			const uint16_t nb_tx = rte_eth_tx_burst(port^1, 0, bufs, nb_rx);
			
			if(unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for (buf = nb_tx; buf < nb_rx; buf++)
					rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
}

/*static int
lcore_worker(__rte_unused void *arg)
{
	unsigned lcore_id = rte_lcore_id();
	
	printf("Starting lcore %u ... \n", lcore_id);
	
	return 0;
}*/

int
main(int argc, char** argv)
{
	if(argc < 1) {
		printf("Usage: %s [active_program_dir <active_program_name>] [fid=1]\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	pnemonic_opcode_t instr_set;
	activep4_def_t active_function;
	activep4_context_t ap4_ctxt;

	memset(&instr_set, 0, sizeof(pnemonic_opcode_t));
	memset(&active_function, 0, sizeof(activep4_def_t));
	memset(&ap4_ctxt, 0, sizeof(activep4_context_t));

	int is_active = (argc > 2);
	if(is_active) {
		char* active_dir = argv[1];
		char* active_program_name = argv[2];
		int fid = (argc > 3) ? atoi(argv[3]) : 1;
		read_opcode_action_map(INSTR_SET_PATH, &instr_set);
		read_active_function(&active_function, active_dir, active_program_name);
		// TODO data argument definitions.
		active_function.fid = fid;
		ap4_ctxt.program = &active_function;
		ap4_ctxt.is_active = 1;
		printf("ActiveP4 context initialized for %s.\n", active_program_name);
	}

	struct rte_mempool *mbuf_pool;
	uint16_t nb_ports;
	uint16_t portid;
	
	/*struct option lgopts[] = {
		{ NULL,  0, 0, 0 }
	};
	int opt, option_index;*/
	
	/*static const struct rte_mbuf_dynfield tsc_dynfield_desc = {
		.name = "example_bbdev_dynfield_tsc",
		.size = sizeof(tsc_t),
		.align = __alignof__(tsc_t),
	};*/

	int ret = rte_eal_init(argc, argv);

	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

	/*while((opt = getopt_long(argc, argv, "t", lgopts, &option_index)) != EOF)
		switch (opt) {
		case 't':
			hw_timestamping = 1;
			break;
		default:
			printf(usage, argv[0]);
			return -1;
		}
	optind = 1;*/

	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports < 1)
		rte_exit(EXIT_FAILURE, "Error: at least one port is required.\n");

	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL",
		NUM_MBUFS * nb_ports, MBUF_CACHE_SIZE, 0,
		RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());
	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	/*tsc_dynfield_offset =
		rte_mbuf_dynfield_register(&tsc_dynfield_desc);
	if (tsc_dynfield_offset < 0)
		rte_exit(EXIT_FAILURE, "Cannot register mbuf field\n");*/

	unsigned port_count = 0;
	RTE_ETH_FOREACH_DEV(portid) {
		char portname[32];
		char portargs[256];
		struct rte_ether_addr addr = {0};

		if (++port_count > nb_ports)
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

		if (rte_eal_hotplug_add("vdev", portname, portargs) < 0)
			rte_exit(EXIT_FAILURE, "Cannot create paired port for port %u\n", portid);
	}

	RTE_ETH_FOREACH_DEV(portid)
		if(port_init(portid, mbuf_pool, &ap4_ctxt) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);

	/*unsigned lcore_id;
	RTE_LCORE_FOREACH_WORKER(lcore_id) {
		rte_eal_remote_launch(lcore_worker, NULL, lcore_id);
	}*/

	lcore_main();

	rte_eal_cleanup();

	return 0;
}
