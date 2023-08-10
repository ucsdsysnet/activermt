#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <signal.h>
#include <stddef.h>
#include <inttypes.h>
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_mbuf_dyn.h>
#include <rte_compat.h>
#include <rte_memory.h>
#include <rte_malloc.h>

#include "../../../headers/activep4.h"
#include "../include/types.h"
#include "../include/utils.h"
#include "../include/memory.h"
#include "../include/active.h"

// #define DEBUG
#define STATS
#define INSTR_SET_PATH		"opcode_action_mapping.csv"

int is_running;

static struct rte_mempool* mbuf_pool;
static struct rte_eth_dev_tx_buffer* buffer;
static uint64_t drop_counter;
static void (*rx_handler)(struct rte_mbuf*);

static void 
interrupt_handler(int sig) {
    printf("Exiting ... \n");
    is_running = 0;
}

static inline void
print_usage(char* filename) {
    printf("Usage: %s <option>\n", filename);
    printf("1. Request allocation.\n");
}

static uint16_t
rx_filter(
	uint16_t port_id __rte_unused, 
	uint16_t queue __rte_unused, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	uint16_t max_pkts,
	void *ctxt
) {
	for(int i = 0; i < nb_pkts; i++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[i], char*);
        if(rx_handler != NULL) rx_handler(pkts[i]);
	}

	#ifdef DEBUG
	if(nb_pkts > 0)
		printf("Received %d packets.\n", nb_pkts);
	#endif

	return nb_pkts;
}

static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool)
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

	retval = rte_eth_promiscuous_enable(port);
    if(retval != 0) return retval;

    rte_eth_add_rx_callback(port, 0, rx_filter, NULL);

	return 0;
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
			#ifdef STATS
			if(rx_pkts > 0 || tx_pkts > 0)
				printf("[STATS][%d] RX %lu pkts TX %lu pkts\n", port_id, rx_pkts, tx_pkts);
			#endif
		}
		rte_delay_us_block(DELAY_SEC);
	}

	char filename[50];
	sprintf(filename, "dpdk_stats_%d.csv", port_id);
	FILE *fp = fopen(filename, "w");
	if(fp == NULL) return -1;
	for(int i = 0; i < samples.num_samples; i++) {
		fprintf(fp, "%lu,%lu,%lu\n", samples.ts[i], samples.rx_pkts[i], samples.tx_pkts[i]);
	}
	fclose(fp);
    printf("[STATS] %u samples written to %s.\n", samples.num_samples, filename);
	
	return 0;
}

static int
lcore_rx(void* arg) {

	uint16_t port;

	RTE_ETH_FOREACH_DEV(port) {
		struct rte_eth_dev_info dev_info;
		if(rte_eth_dev_info_get(port, &dev_info) != 0) {
			printf("Error during getting device (port %u)\n", port);
			exit(EXIT_FAILURE);
		}
		if(rte_eth_dev_socket_id(port) > 0 && rte_eth_dev_socket_id(port) != (int)rte_socket_id()) {
			printf("WARNING, port %u is on remote NUMA node to polling thread.\n\tPerformance will not be optimal.\n", port);
		}
		else {
			printf("Port %d on local NUMA node.\n", port);
		}
		printf("Port %d Queues RX %d Tx %d\n", port, dev_info.nb_rx_queues, dev_info.nb_tx_queues);
	}

	printf("\nCore %u receiving packets. [Ctrl+C to quit]\n", rte_lcore_id());

	const int qid = 0;

	while(is_running) {
		RTE_ETH_FOREACH_DEV(port) {
			struct rte_mbuf* bufs[BURST_SIZE];
			const uint16_t nb_rx = rte_eth_rx_burst(port, qid, bufs, BURST_SIZE);
			
			if (unlikely(nb_rx == 0))
				continue;

            #ifdef DEBUG
            printf("[DEBUG] rx %d packets on port %d", nb_rx, port);
            #endif
		}
	}

    printf("[INFO] rx thread exiting ... \n");
}

/* Tests */

static void
rx_handler_allocation_request(struct rte_mbuf* mbuf) {
    
    char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
    
    struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
    bufptr += sizeof(struct rte_ether_hdr);
    
    if(ntohs(hdr_eth->ether_type) != AP4_ETHER_TYPE_AP4) return;

    activep4_ih* hdr_ap4 = (activep4_ih*)bufptr;

    uint16_t flags = ntohs(hdr_ap4->flags);

    printf("[DEBUG] active response flags 0x%x\n", flags);
}

static int
lcore_allocation_request(void* arg) {

    printf("[INFO] running test for allocation request ... \n");

    char* dev = "ens4";
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

    int qid = 1;

    uint64_t now, elapsed_us;

    struct rte_mbuf* mbuf;

    activep4_context_t ctxt;
    pnemonic_opcode_t instr_set;

	memset(&instr_set, 0, sizeof(pnemonic_opcode_t));
    memset(&ctxt, 0, sizeof(activep4_context_t));

    ctxt.program = (activep4_def_t*)rte_zmalloc(NULL, sizeof(activep4_def_t), 0);

    read_opcode_action_map(INSTR_SET_PATH, &instr_set);

    ctxt.instr_set = &instr_set;
    ctxt.program->fid = 1;
    ctxt.ipv4_srcaddr = ipv4_ifaceaddr;

    read_active_function(ctxt.program, "../../../apps/cache/active", "cacheread");

    rx_handler = rx_handler_allocation_request;

    while(is_running) {
        if((mbuf = rte_pktmbuf_alloc(mbuf_pool)) != NULL) {
            construct_reqalloc_packet(mbuf, PORT_PETH, &ctxt);
            rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
            rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
        }
        if((mbuf = rte_pktmbuf_alloc(mbuf_pool)) != NULL) {
            construct_getalloc_packet(mbuf, PORT_PETH, &ctxt);
            rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
            rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
        }
        break;
    }

    return 0;
}

int main(int argc, char** argv) {

    if(argc < 2) {
        print_usage(argv[0]);
        exit(EXIT_FAILURE);
    }

    int option = atoi(argv[1]);

    int ret = rte_eal_init(argc, argv);

	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

    uint16_t portid;

    uint16_t nb_ports = rte_eth_dev_count_avail();

    mbuf_pool = rte_pktmbuf_pool_create(
        "MBUF_POOL",
		NUM_MBUFS * nb_ports, 
        MBUF_CACHE_SIZE, 
        0,
		RTE_MBUF_DEFAULT_BUF_SIZE, 
        rte_socket_id()
    );
	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");

    buffer = rte_zmalloc(NULL, RTE_ETH_TX_BUFFER_SIZE(BURST_SIZE), 0);
	if(buffer == NULL)
		rte_exit(EXIT_FAILURE, "Cannot allocate TX buffer for control thread.");
	if(rte_eth_tx_buffer_init(buffer, BURST_SIZE) != 0)
		rte_exit(EXIT_FAILURE, "Cannot initialize TX buffer for control thread.");
	if(rte_eth_tx_buffer_set_err_callback(buffer, rte_eth_tx_buffer_count_callback, &drop_counter) < 0)
		rte_exit(EXIT_FAILURE, "Cannot set error callback for TX buffer for control thread.");

    is_running = 1;
    signal(SIGINT, interrupt_handler);

    unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);

    int ports[RTE_MAX_ETHPORTS];
	RTE_ETH_FOREACH_DEV(portid) {
		ports[portid] = portid;
		if(port_init(portid, mbuf_pool) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);
		rte_eal_remote_launch(lcore_stats, (void*)&ports[portid], lcore_id);
		lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
        rte_eal_remote_launch(lcore_rx, (void*)&ports[portid], lcore_id);
		lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	}

    rx_handler = NULL;

    switch(option) {
        case 1:
            rte_eal_remote_launch(lcore_allocation_request, NULL, lcore_id);
            break;
        default:
            printf("Unknown option: %d\n", option);
            print_usage(argv[0]);
    }

    while(is_running) {
        rte_delay_us(100);
    }

    printf("[INFO] main thread exiting ... \n");

    return 0;
}