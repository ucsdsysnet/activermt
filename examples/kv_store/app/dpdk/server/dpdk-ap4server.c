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

#include "../../../../../include/c/common/activep4.h"

// #define DEBUG

#define RX_RING_SIZE 	1024
#define TX_RING_SIZE 	1024

#define NUM_MBUFS 		8191
#define MBUF_CACHE_SIZE 250
#define BURST_SIZE 		32

#define IP_PROTO_AP4	0x83B2

static const struct rte_eth_conf port_conf_default = {
	.rxmode = {
		.max_lro_pkt_size = RTE_ETHER_MAX_LEN,
	},
};

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


static inline int
process_packet(char* pkt, int pktlen) {
	
	struct rte_ether_hdr* 	eth_hdr;
	struct rte_ipv4_hdr*	ipv4_hdr;
	struct rte_udp_hdr*		udp_hdr;
	struct rte_ether_addr	tmp_addr_eth;
	rte_be32_t 				tmp_addr_ipv4;

	char* updatedpkt = pkt;

	// Ethernet

	eth_hdr = (struct rte_ether_hdr*)pkt;
	pkt += sizeof(struct rte_ether_hdr);

	tmp_addr_eth = eth_hdr->src_addr;
	eth_hdr->src_addr = eth_hdr->dst_addr;
	eth_hdr->dst_addr = tmp_addr_eth;

	int ip_offset = 0;

	uint16_t ether_type = ntohs(eth_hdr->ether_type);

	#ifdef DEBUG
	printf("[DEBUG] Ethertype %x active packet.\n", ether_type);
	#endif

	if(ether_type == IP_PROTO_AP4) {
		activep4_ih* ap4_ih = (activep4_ih*)pkt;
		pkt += sizeof(activep4_ih);
		ip_offset += sizeof(activep4_ih);
		uint16_t flags = ntohs(ap4_ih->flags);
		#ifdef DEBUG
		printf("[DEBUG] Active flags %x\n", flags);
		#endif
		if(flags & AP4FLAGMASK_OPT_ARGS) {
			activep4_data_t* ap4_args = (activep4_data_t*)pkt;
			printf("[DEBUG] active args (%u,%u,%u,%u)\n", ntohl(ap4_args->data[0]), ntohl(ap4_args->data[1]), ntohl(ap4_args->data[2]), ntohl(ap4_args->data[3]));
			pkt += sizeof(activep4_data_t);
			ip_offset += sizeof(activep4_data_t);
		}
		// eth_hdr->ether_type = htons(IPPROTO_IP);
	}

	// IPv4

	ipv4_hdr = (struct rte_ipv4_hdr*)pkt;
	pkt += sizeof(struct rte_ipv4_hdr);

	tmp_addr_ipv4 = ipv4_hdr->src_addr;
	ipv4_hdr->src_addr = ipv4_hdr->dst_addr;
	ipv4_hdr->dst_addr = tmp_addr_ipv4;

	// UDP 

	udp_hdr = (struct rte_udp_hdr*)pkt;
	pkt += sizeof(struct rte_udp_hdr);

	// Update packet data

	// int ether_len = sizeof(struct rte_ether_hdr);
	// for(int i = 0; i < pktlen - ether_len - ip_offset; i++)
	// 	updatedpkt[ether_len + i] = updatedpkt[ether_len + ip_offset + i];

	// pkt = updatedpkt;
	
	// return (pktlen - ip_offset);
	return pktlen;
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
			int i;
			char *p;
			const uint16_t nb_rx = rte_eth_rx_burst(port, 0,
					bufs, BURST_SIZE);

			if (unlikely(nb_rx == 0))
				continue;

			for(i = 0; i < nb_rx; i++) {
				p = rte_pktmbuf_mtod(bufs[i], char *);
				bufs[i]->pkt_len = process_packet(p, bufs[i]->pkt_len);
				bufs[i]->data_len = bufs[i]->pkt_len;
			}

			#ifdef DEBUG
			printf("[DEBUG] Received (processed) %d packets.\n", nb_rx);
			#endif

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
