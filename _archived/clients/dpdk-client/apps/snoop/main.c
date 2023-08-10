#include <stdlib.h>
#include <signal.h>
#include <math.h>
#include <rte_malloc.h>
#include <rte_ethdev.h>

#define DEBUG

#define NUM_RX_QUEUES		1
#define NUM_TX_QUEUES		1
#define RX_RING_SIZE 		1024
#define TX_RING_SIZE 		1024
#define NUM_MBUFS 			8191
#define MBUF_CACHE_SIZE 	250
#define TX_BURST_SIZE		1
#define RX_BURST_SIZE		32
#define NUM_SAMPLES			1000
#define ETH_TYPE_SNOOP		0x83b3

typedef struct {
    uint32_t	pipe_id;
	uint32_t	ingress_ts;
	uint32_t	egress_ts;
	uint32_t	addr;
	uint32_t	data;
} __attribute__((packed)) snoop_h;

typedef struct {
	uint64_t	elapsed_ns;
} measurement_t;

int 					is_running = 0;
int 					port_id = 0;
static struct 			rte_mempool* mbuf_pool;
static struct 			rte_eth_dev_tx_buffer* buffer;
static uint64_t 		drop_counter;
static measurement_t	data[NUM_SAMPLES];
static int				current_sample = 0;

static inline unsigned
poisson(double lambda) {
    unsigned n = 0;
    double lim = exp(-lambda);
    for(double i = (double)rand()/INT_MAX; i > lim; i *= (double)rand()/INT_MAX) n++;
    return n;
}

static void 
interrupt_handler(int sig) {
    is_running = 0;
}

// static void
// print_usage(char** argv) {
//     rte_exit(EXIT_FAILURE, "Usage: %s\n", argv[0]);
// }

static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool)
{
	assert(mbuf_pool != NULL);

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
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Error during getting device (port %u) info: %s\n", port, strerror(-retval));
		return retval;
	}

	printf("Device %d supports %d TX queues.\n", port, dev_info.max_tx_queues);

	const uint16_t rx_rings = NUM_RX_QUEUES;
	const uint16_t tx_rings = NUM_TX_QUEUES;

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
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Failed to get MAC address on port %u: %s\n", port, rte_strerror(-retval));
		return retval;
	}
	printf(
		"Port %u MAC: %02"PRIx8" %02"PRIx8" %02"PRIx8" %02"PRIx8" %02"PRIx8" %02"PRIx8"\n",
		(unsigned)port,
		RTE_ETHER_ADDR_BYTES(&addr)
	);

	retval = rte_eth_promiscuous_enable(port);
    if(retval != 0) return retval;

	return 0;
}

static int
lcore_rx(void* arg) {

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "RX thread running for port %d on lcore %d\n", port_id, rte_lcore_id());

    struct rte_eth_dev_info dev_info;
    if(rte_eth_dev_info_get(port_id, &dev_info) != 0) {
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Error during getting device (port %u)\n", port_id);
        exit(EXIT_FAILURE);
    }

    if(rte_eth_dev_socket_id(port_id) > 0 && rte_eth_dev_socket_id(port_id) != (int)rte_socket_id()) {
        printf("WARNING, port %u is on remote NUMA node to polling thread.\n\tPerformance will not be optimal.\n", port_id);
    } else {
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d on local NUMA node.\n", port_id);
    }

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d Queues RX %d Tx %d\n", port_id, dev_info.nb_rx_queues, dev_info.nb_tx_queues);

    const int qid = 0;

    while(is_running) {
		struct rte_mbuf* bufs[RX_BURST_SIZE];
        const uint16_t nb_rx = rte_eth_rx_burst(port_id, qid, bufs, RX_BURST_SIZE);
        
        if (unlikely(nb_rx == 0))
            continue;

        for(int p = 0; p < nb_rx; p++) {

            char* bufptr = rte_pktmbuf_mtod(bufs[p], char*);

            struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;

			if(ntohs(hdr_eth->ether_type) == ETH_TYPE_SNOOP) {
				snoop_h* snoop = (snoop_h*)(bufptr + sizeof(struct rte_ether_hdr));
				uint32_t pipe_id = ntohl(snoop->pipe_id);
				uint32_t ingress_ts = ntohl(snoop->ingress_ts);
				uint32_t egress_ts = ntohl(snoop->egress_ts);
				uint32_t heap_data = ntohl(snoop->data);
				uint64_t elapsed_ns = egress_ts - ingress_ts;
				// uint64_t elapsed_ns = snoop->egress_ts - snoop->ingress_ts;
				data[current_sample++].elapsed_ns = elapsed_ns;
				rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DATA] %u,%u,%u,%u,%u\n", pipe_id, heap_data, ingress_ts, egress_ts, (uint32_t)elapsed_ns);
			}
        }

        for(uint16_t buf = 0; buf < nb_rx; buf++)
            rte_pktmbuf_free(bufs[buf]);
	}

    return 0;
}

static int
lcore_tx(void* arg) {

	const int qid = 0;

	struct rte_mempool* mempool = rte_pktmbuf_pool_create(
		"MBUF_POOL_CONTROL",
		NUM_MBUFS, 
		MBUF_CACHE_SIZE, 
		0,
		RTE_MBUF_DEFAULT_BUF_SIZE, 
		rte_socket_id()
	);

	if(mempool == NULL) {
		is_running = 0;
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");
	}
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Memory pool created for socket %d (control)\n", rte_socket_id());

	struct rte_mbuf* mbuf = NULL;

	for(int i = 0; i < NUM_SAMPLES; i++) {
		// uint64_t now = rte_rdtsc_precise();
		if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
			char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
			struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
			memset(bufptr, 0, sizeof(struct rte_ether_hdr) + sizeof(snoop_h));
			eth->ether_type = htons(ETH_TYPE_SNOOP);
			mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(snoop_h);
			mbuf->data_len = mbuf->pkt_len;
			rte_eth_tx_buffer(port_id, qid, buffer, mbuf);
			rte_eth_tx_buffer_flush(port_id, qid, buffer);
		}
		rte_delay_us(10);
	}

	rte_delay_ms(100);

	is_running = 0;

	return 0;
}

/*
	Objectives:
	1. Measure hop-to-hop latency.
	2. Measure one-hop synchronization latency (pessimistic).
*/
int
main(int argc, char** argv)
{
	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

    is_running = 1;
	signal(SIGINT, interrupt_handler);

    FILE *logfd = fopen("rte_log_rmt_bench_snoop.log", "w");
	if(logfd == NULL || rte_openlog_stream(logfd) < 0) {
		rte_exit(EXIT_FAILURE, "Unable to create log file!");
	} else {
		rte_log_register_type_and_pick_level("SNOOP", RTE_LOG_INFO);
	}

	// initialize ports.

    uint16_t nb_ports;

	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports > 1)
		rte_exit(EXIT_FAILURE, "Error: multiple ports detected!\n");

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Number of sockets: %d\n", rte_socket_count());

	mbuf_pool = rte_pktmbuf_pool_create(
		"MBUF_POOL",
		NUM_MBUFS, 
		MBUF_CACHE_SIZE, 
		0,
		RTE_MBUF_DEFAULT_BUF_SIZE, 
		rte_socket_id()
	);
	if (mbuf_pool == NULL)
		rte_exit(EXIT_FAILURE, "Cannot create mbuf pool\n");
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Memory pool created for socket %d\n", rte_socket_id());

    buffer = (struct rte_eth_dev_tx_buffer*)rte_zmalloc(NULL, RTE_ETH_TX_BUFFER_SIZE(TX_BURST_SIZE), 0);
	if(buffer == NULL)
		rte_exit(EXIT_FAILURE, "Cannot allocate TX buffer for control thread.");
	if(rte_eth_tx_buffer_init(buffer, TX_BURST_SIZE) != 0)
		rte_exit(EXIT_FAILURE, "Cannot initialize TX buffer for control thread.");
	if(rte_eth_tx_buffer_set_err_callback(buffer, rte_eth_tx_buffer_count_callback, &drop_counter) < 0)
		rte_exit(EXIT_FAILURE, "Cannot set error callback for TX buffer for control thread.");

    const uint16_t portid = 0;

	if(port_init(portid, mbuf_pool) != 0)
		rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);

	unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);
    // assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());

	rte_eal_remote_launch(lcore_rx, NULL, lcore_id);

	lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	// assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());

	rte_eal_remote_launch(lcore_tx, NULL, lcore_id);

	rte_delay_ms(1000);

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MAIN] starting experiment ... \n");

    while(is_running) {
		rte_delay_us(100);
	}

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MAIN] experiment complete.\n");

	rte_eal_cleanup();

	return 0;
}
