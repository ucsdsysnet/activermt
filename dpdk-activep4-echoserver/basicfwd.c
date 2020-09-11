/* SPDX-License-Identifier: BSD-3-Clause
 * Copyright(c) 2010-2015 Intel Corporation
 */

#include <stdint.h>
#include <inttypes.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_ether.h>
#include <rte_ip.h>
#include <rte_udp.h>

#define RX_RING_SIZE 1024
#define TX_RING_SIZE 1024

#define KVSTORE_SIZE	65536
#define MAX_CODELEN		1280
#define NUM_MBUFS 8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 32

#define FLAG_MARKED(x)	(x & 0x0800) >> 11
#define FLAG_MEMFAULT(x) 

static const struct rte_eth_conf port_conf_default = {
	.rxmode = {
		.max_rx_pkt_len = RTE_ETHER_MAX_LEN,
	},
};

typedef struct {
	uint32_t padding_0;
	uint16_t padding_1;
	uint64_t timestamp;
	uint16_t magic;
} __attribute__((__packed__)) tstamp_t;

typedef struct {
	uint16_t	flags;
	uint16_t	fid;
	uint16_t	acc;
	uint16_t	acc2;
	uint16_t	id;
	uint16_t	freq;
} __attribute__((__packed__)) pg_active_initial_hdr;

typedef struct {
	uint8_t		flags_label;
	uint8_t		opcode;
	uint16_t	args;
} __attribute__((__packed__)) pg_active_instruction_hdr;

uint16_t kv_store[KVSTORE_SIZE];
uint16_t bytecode_cacheread_response[MAX_CODELEN][3];
uint16_t codelen_cacheread_response;
uint16_t caching_frequency_threshold;
uint16_t memaddr_base, memaddr_pagemask;

/* basicfwd.c: Basic DPDK skeleton forwarding example. */

/*
 * Initializes a given port using global settings and with the RX buffers
 * coming from the mbuf_pool passed as a parameter.
 */
static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool)
{
	struct rte_eth_conf port_conf = port_conf_default;
	const uint16_t rx_rings = 1, tx_rings = 1;
	uint16_t nb_rxd = RX_RING_SIZE;
	uint16_t nb_txd = TX_RING_SIZE;
	int retval;
	uint16_t q;
	struct rte_eth_dev_info dev_info;
	struct rte_eth_txconf txconf;

	if (!rte_eth_dev_is_valid_port(port))
		return -1;

	retval = rte_eth_dev_info_get(port, &dev_info);
	if (retval != 0) {
		printf("Error during getting device (port %u) info: %s\n",
				port, strerror(-retval));
		return retval;
	}

	if (dev_info.tx_offload_capa & DEV_TX_OFFLOAD_MBUF_FAST_FREE)
		port_conf.txmode.offloads |=
			DEV_TX_OFFLOAD_MBUF_FAST_FREE;

	/* Configure the Ethernet device. */
	retval = rte_eth_dev_configure(port, rx_rings, tx_rings, &port_conf);
	if (retval != 0)
		return retval;

	retval = rte_eth_dev_adjust_nb_rx_tx_desc(port, &nb_rxd, &nb_txd);
	if (retval != 0)
		return retval;

	/* Allocate and set up 1 RX queue per Ethernet port. */
	for (q = 0; q < rx_rings; q++) {
		retval = rte_eth_rx_queue_setup(port, q, nb_rxd,
				rte_eth_dev_socket_id(port), NULL, mbuf_pool);
		if (retval < 0)
			return retval;
	}

	txconf = dev_info.default_txconf;
	txconf.offloads = port_conf.txmode.offloads;
	/* Allocate and set up 1 TX queue per Ethernet port. */
	for (q = 0; q < tx_rings; q++) {
		retval = rte_eth_tx_queue_setup(port, q, nb_txd,
				rte_eth_dev_socket_id(port), &txconf);
		if (retval < 0)
			return retval;
	}

	/* Start the Ethernet port. */
	retval = rte_eth_dev_start(port);
	if (retval < 0)
		return retval;

	/* Display the port MAC address. */
	struct rte_ether_addr addr;
	retval = rte_eth_macaddr_get(port, &addr);
	if (retval != 0)
		return retval;

	printf("Port %u MAC: %02" PRIx8 " %02" PRIx8 " %02" PRIx8
			   " %02" PRIx8 " %02" PRIx8 " %02" PRIx8 "\n",
			port,
			addr.addr_bytes[0], addr.addr_bytes[1],
			addr.addr_bytes[2], addr.addr_bytes[3],
			addr.addr_bytes[4], addr.addr_bytes[5]);

	/* Enable RX in promiscuous mode for the Ethernet device. */
	retval = rte_eth_promiscuous_enable(port);
	if (retval != 0)
		return retval;

	return 0;
}

static inline void
sleep_ns(uint64_t duration_ns)
{
	uint64_t i, then, now, elapsed_ns;
	then = rte_get_timer_cycles();
	elapsed_ns = 0;
	while(elapsed_ns < duration_ns) {
		now = rte_get_timer_cycles();
		elapsed_ns = (now - then) * 1E9 / rte_get_timer_hz();
	}
}

static inline void
active_add_instruction(pg_active_instruction_hdr *instr, uint8_t label, uint8_t opcode, uint16_t args)
{
	instr->flags_label = label;
	instr->opcode = opcode;
	instr->args = rte_bswap16(args);
}

static inline void
active_program_insert(pg_active_instruction_hdr *instr, uint16_t bytecode[][3], uint16_t codelen)
{
	uint16_t i;
	for(i = 0; i < codelen; i++) {
		active_add_instruction(instr, bytecode[i][0], bytecode[i][1], bytecode[i][2]);
		instr++;
	}
}

static inline void
customize_cacheread_response(pg_active_instruction_hdr *instr, uint16_t key, uint16_t value, uint16_t freq)
{
	uint16_t i;
	uint16_t bytecode[MAX_CODELEN][3];
	for(i = 0; i < codelen_cacheread_response; i++) {
		bytecode[i][0] = bytecode_cacheread_response[i][0];
		bytecode[i][1] = bytecode_cacheread_response[i][1];
		bytecode[i][2] = bytecode_cacheread_response[i][2];
	}
	bytecode[0][2] = key;
	bytecode[2][2] = memaddr_pagemask;
	bytecode[3][2] = memaddr_base;
	bytecode[7][2] = freq;
	bytecode[13][2] = key;
	bytecode[16][2] = value;
	bytecode[19][2] = freq;
	active_program_insert(instr, bytecode, codelen_cacheread_response);
}

static inline void
read_active_program(uint16_t bytecode[][3], uint16_t *codelen, char *src_file)
{
	uint16_t flags_goto, opcode, arg;
	FILE* fptr = fopen(src_file, "r");
	*codelen = 0;
	if(fptr != NULL) {
		while(fscanf(fptr, "%hd,%hd,%hd", &flags_goto, &opcode, &arg) != EOF && *codelen < MAX_CODELEN) {
			bytecode[*codelen][0] = flags_goto;
			bytecode[*codelen][1] = opcode;
			bytecode[*codelen][2] = arg;
			(*codelen)++;
		}
		fclose(fptr);
	}
}

/*
 * The lcore main. This is the main thread that does the work, reading from
 * an input port and writing to an output port.
 */
static __attribute__((noreturn)) void
lcore_main(void)
{
	uint16_t port;

	/*
	 * Check that the port is on the same NUMA node as the polling thread
	 * for best performance.
	 */
	RTE_ETH_FOREACH_DEV(port)
		if (rte_eth_dev_socket_id(port) > 0 &&
				rte_eth_dev_socket_id(port) !=
						(int)rte_socket_id())
			printf("WARNING, port %u is on remote NUMA node to "
					"polling thread.\n\tPerformance will "
					"not be optimal.\n", port);

	printf("\nCore %u forwarding packets. [Ctrl+C to quit]\n",
			rte_lcore_id());

	/* Run until the application is quit or killed. */
	for (;;) {
		/*
		 * Receive packets on a port and forward them on the paired
		 * port. The mapping is 0 -> 1, 1 -> 0, 2 -> 3, 3 -> 2, etc.
		 */
		RTE_ETH_FOREACH_DEV(port) {

			/* Get burst of RX packets, from first port of pair. */
			struct rte_mbuf *bufs[BURST_SIZE];
			struct rte_ipv4_hdr	*ipv4_hdr;
			pg_active_initial_hdr *activep4_hdr;
			pg_active_instruction_hdr *instr;

			rte_be32_t tmp_addr;
			uint8_t	hasflag_marked;
			uint16_t fid, key, value, flags, freq;

			int i;
			char *p;

			const uint16_t nb_rx = rte_eth_rx_burst(port, 0,
					bufs, BURST_SIZE);

			if (unlikely(nb_rx == 0))
				continue;

			for(i = 0; i < nb_rx; i++) {
				p = rte_pktmbuf_mtod(bufs[i], char *);
				p += sizeof(struct rte_ether_hdr);

				// swap src,dst IPs
				ipv4_hdr = (struct rte_ipv4_hdr*) p;
				tmp_addr = ipv4_hdr->src_addr;
				ipv4_hdr->src_addr = ipv4_hdr->dst_addr;
				ipv4_hdr->dst_addr = tmp_addr;
				
				p += sizeof(struct rte_ipv4_hdr);
				p += sizeof(struct rte_udp_hdr);
				p += sizeof(tstamp_t);

				// serve request
				activep4_hdr = (pg_active_initial_hdr*) p;
				flags = rte_bswap16(activep4_hdr->flags);
				fid = rte_bswap16(activep4_hdr->fid);
				hasflag_marked = FLAG_MARKED(flags);
				if(fid != 10) continue;
				
				key = rte_bswap16(activep4_hdr->acc2);
				freq = rte_bswap16(activep4_hdr->acc);
				printf("[REQUEST] key=%hu\n", key);
				value = kv_store[key];
				activep4_hdr->acc = rte_bswap16(value);
				if(hasflag_marked == 1) {
					// insert active program
					printf("hot item freq=%hu\n", freq);
					activep4_hdr->flags = 0;
					//bufs[i]->data_len = 28 + codelen_cacheread_response * 4;
					//bufs[i]->pkt_len = 42 + bufs[i]->data_len;
					instr = (pg_active_instruction_hdr*) ((char*) activep4_hdr + sizeof(pg_active_initial_hdr));
					customize_cacheread_response(instr, key, value, freq);
				}
			}

			/* Send burst of TX packets, to second port of pair. */
			const uint16_t nb_tx = rte_eth_tx_burst(port, 0,
					bufs, nb_rx);

			/* Free any unsent packets. */
			if (unlikely(nb_tx < nb_rx)) {
				uint16_t buf;
				for (buf = nb_tx; buf < nb_rx; buf++)
					rte_pktmbuf_free(bufs[buf]);
			}
		}
	}
}

/*
 * The main function, which does initialization and calls the per-lcore
 * functions.
 */
int
main(int argc, char *argv[])
{
	struct rte_mempool *mbuf_pool;
	unsigned nb_ports;
	uint16_t portid;
	uint32_t key;
	char filename[100];

	for(key = 0; key < KVSTORE_SIZE; key++) kv_store[key] = KVSTORE_SIZE - key - 1;
	strcpy(filename, "cache_read_response.csv");
	read_active_program(bytecode_cacheread_response, &codelen_cacheread_response, filename);
	memaddr_base = 0;
	memaddr_pagemask = 0x000F;

	/* Initialize the Environment Abstraction Layer (EAL). */
	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");

	argc -= ret;
	argv += ret;

	/* Check that there is an even number of ports to send/receive on. */
	nb_ports = 1;
	/*nb_ports = rte_eth_dev_count_avail();
	if (nb_ports < 2 || (nb_ports & 1))
		rte_exit(EXIT_FAILURE, "Error: number of ports must be even\n");*/

	/* Creates a new mempool in memory to hold the mbufs. */
	mbuf_pool = rte_pktmbuf_pool_create("MBUF_POOL", NUM_MBUFS * nb_ports,
		MBUF_CACHE_SIZE, 0, RTE_MBUF_DEFAULT_BUF_SIZE, rte_socket_id());

	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

	/* Initialize all ports. */
	RTE_ETH_FOREACH_DEV(portid)
		if (port_init(portid, mbuf_pool) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16 "\n",
					portid);

	if (rte_lcore_count() > 1)
		printf("\nWARNING: Too many lcores enabled. Only 1 used.\n");

	/* Call lcore_main on the master core only. */
	lcore_main();

	return 0;
}
