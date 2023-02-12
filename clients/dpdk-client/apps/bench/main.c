#include <stdlib.h>
#include <signal.h>
#include <math.h>
#include <rte_malloc.h>
#include <rte_ethdev.h>

#include "../../include/types.h"
#include "../../include/utils.h"
#include "../../include/memory.h"
#include "../../include/active.h"

#include "rx.h"
#include "control.h"

#define DEBUG_BENCH

#define INSTR_SET_PATH		        "../../../../config/opcode_action_mapping.csv"
#define ACTIVE_DIR_CACHE            "../../../../apps/cache/active"
#define ACTIVE_DIR_LB               "../../../../apps/cheetahlb/active"
#define ACTIVE_PROGRAM_CACHE        "cacheread"
#define ACTIVE_PROGRAM_MONITOR	    "freqitem"
#define ACTIVE_PROGRAM_LB           "cheetahlb-syn"

#define APP_IPV4_ADDR               0x0100000a
#define APP_IPV4_DSTADDR            0x0100000a
#define NUM_ACTIVE_PROGRAMS         3
#define MAX_CONCURRENT				100
#define POISSON_LAMBDA				1
#define ARRIVAL_DELAY_MS			2000

#define PID_CACHEREAD               0
#define PID_FREQITEM                1
#define PID_LB                      2

static int DEMANDS[NUM_ACTIVE_PROGRAMS];

int memory_consume_bench(memory_t* mem, void* context) { return 0; }
int memory_invalidate_bench(memory_t* mem, void* context) { return 0; }
int memory_reset_bench(memory_t* mem, void* context) { return 0; }
void timer_bench(void* arg) {}
void shutdown_bench(int id, void* context) {}

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

static void
print_usage(char** argv) {
    rte_exit(EXIT_FAILURE, "Usage: %s [duration_ticks=1]\n", argv[0]);
}

static __rte_always_inline void 
activate_application(activep4_context_t* ctxt, activep4_def_t* active_programs, int pid, uint16_t fid) {

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] activating application with program: %s ... \n", fid, active_programs[pid].name);

	ctxt->fid = fid;

	ctxt->programs[0] = rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
	ctxt->programs[0]->pid = 0;
	rte_memcpy(ctxt->programs[0], &active_programs[pid], sizeof(activep4_def_t));
	rte_memcpy(ctxt->programs[0]->mutant.code, active_programs[pid].code, sizeof(active_programs[pid].code));
	ctxt->programs[0]->mutant.proglen = active_programs[pid].proglen;

	ctxt->active_tx_enabled = true;
	ctxt->active_heartbeat_enabled = true;
	ctxt->active_timer_enabled = true;
	ctxt->timer_interval_us = DEFAULT_TI_US;
	ctxt->is_elastic = true;
	ctxt->status = ACTIVE_STATE_INITIALIZING;
	ctxt->ipv4_srcaddr = APP_IPV4_ADDR;

	ctxt->app_context = NULL;
	ctxt->memory_consume = memory_consume_bench;
	ctxt->memory_invalidate = memory_invalidate_bench;
	ctxt->memory_reset = memory_reset_bench;
	ctxt->shutdown = shutdown_bench;
	ctxt->timer = timer_bench;

	int demand[NUM_STAGES];
	memset(demand, DEMANDS[pid], NUM_STAGES * sizeof(int));
	set_memory_demand_per_stage(ctxt, demand);

	ctxt->is_active = true;
}

static __rte_always_inline void
deactivate_application(activep4_context_t* ctxt) {
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] deactivating application with program: %s ... \n", ctxt->fid, ctxt->programs[0]->name);
	ctxt->status = ACTIVE_STATE_DEALLOCATING;
}

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
	const uint16_t tx_rings = (dev_info.max_tx_queues > NUM_TX_QUEUES) ? NUM_TX_QUEUES : dev_info.max_tx_queues;

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

int
main(int argc, char** argv)
{
	int duration_ticks = (argc > 1) ? atoi(argv[1]) : 1;

    if(duration_ticks <= 0) print_usage(argv);

	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

    is_running = 1;
	signal(SIGINT, interrupt_handler);

    FILE *logfd = fopen("rte_log_active_bench.log", "w");
	if(logfd == NULL || rte_openlog_stream(logfd) < 0) {
		rte_exit(EXIT_FAILURE, "Unable to create log file!");
	} else {
		rte_log_register_type_and_pick_level("AP4", RTE_LOG_INFO);
	}

    pnemonic_opcode_t instr_set;
    memset(&instr_set, 0, sizeof(pnemonic_opcode_t));
    read_opcode_action_map(INSTR_SET_PATH, &instr_set);

    // read active programs.

    activep4_def_t* active_programs = (activep4_def_t*)rte_zmalloc(NULL, NUM_ACTIVE_PROGRAMS * sizeof(activep4_def_t), 0);
    if(active_programs == NULL) {
        rte_exit(EXIT_FAILURE, "Unable to allocate memory for active programs!\n");
    }

    read_active_function(&active_programs[PID_CACHEREAD], ACTIVE_DIR_CACHE, ACTIVE_PROGRAM_CACHE);
    strcpy(active_programs[PID_CACHEREAD].name, ACTIVE_PROGRAM_CACHE);
	DEMANDS[PID_CACHEREAD] = 1;

	read_active_function(&active_programs[PID_FREQITEM], ACTIVE_DIR_CACHE, ACTIVE_PROGRAM_MONITOR);
    strcpy(active_programs[PID_FREQITEM].name, ACTIVE_PROGRAM_MONITOR);
	DEMANDS[PID_FREQITEM] = 16;

    read_active_function(&active_programs[PID_LB], ACTIVE_DIR_LB, ACTIVE_PROGRAM_LB);
    strcpy(active_programs[PID_LB].name, ACTIVE_PROGRAM_LB);
	DEMANDS[PID_LB] = 2;

	// initialize active context pool.

	activep4_context_t* ctxt = (activep4_context_t*)rte_zmalloc(NULL, MAX_CONCURRENT * sizeof(activep4_context_t), 0);
	if(ctxt == NULL) rte_exit(EXIT_FAILURE, "Unable to allocate memory for active context!\n");

	for(int i = 0; i < MAX_CONCURRENT; i++) {
		ctxt[i].instr_set = &instr_set;
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

    buffer = (struct rte_eth_dev_tx_buffer*)rte_zmalloc(NULL, RTE_ETH_TX_BUFFER_SIZE(BURST_SIZE), 0);
	if(buffer == NULL)
		rte_exit(EXIT_FAILURE, "Cannot allocate TX buffer for control thread.");
	if(rte_eth_tx_buffer_init(buffer, BURST_SIZE) != 0)
		rte_exit(EXIT_FAILURE, "Cannot initialize TX buffer for control thread.");
	if(rte_eth_tx_buffer_set_err_callback(buffer, rte_eth_tx_buffer_count_callback, &drop_counter) < 0)
		rte_exit(EXIT_FAILURE, "Cannot set error callback for TX buffer for control thread.");

    unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);
    assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());

    const uint16_t portid = 0;

	if(port_init(portid, mbuf_pool) != 0)
		rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);

	rx_config_t rx_config;
	memset(&rx_config, 0, sizeof(rx_config));
	lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
	rx_config.ctxt = ctxt;
	rx_config.num_instances = MAX_CONCURRENT;
	rx_config.port_id = portid;
	rte_eal_remote_launch(lcore_rx, (void*)&rx_config, lcore_id);

	control_config_t ctrl_config;
    memset(&ctrl_config, 0, sizeof(ctrl_config));
	lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
	ctrl_config.ctxt = ctxt;
	ctrl_config.num_instances = MAX_CONCURRENT;
	ctrl_config.port_id = portid;
	rte_eal_remote_launch(lcore_control, (void*)&ctrl_config, lcore_id);

	rte_delay_ms(1000);

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MAIN] starting experiment for %d ticks ... \n", duration_ticks);

    uint16_t fid = 1;
	int idx = 0;

    for(int i = 0; i < duration_ticks && is_running; i++) {

		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MAIN] tick %d\n", i);

        unsigned num_arrivals = poisson(POISSON_LAMBDA);
        unsigned num_departures = poisson(POISSON_LAMBDA);

		if(num_arrivals > 1) num_arrivals = 1;
		if(num_departures > 1) num_departures = 1;

		#ifdef DEBUG_BENCH
		printf("[DEBUG] arrivals %u departures %u\n", num_arrivals, num_departures);
		#endif

        for(int j = 0; j < num_departures && ctrl_config.num_active > 0; j++) {
			int m = rand() % ctrl_config.num_active;
            for(int a = 0; a < ctrl_config.num_active && m >= 0; a++) {
				if(ctxt[a].is_active == true) {
					if(m-- == 0) {
						deactivate_application(&ctxt[a]);
						ctrl_config.num_active--;
						break;
					}
				}
			}
        }

        for(int j = 0; j < num_arrivals; j++) {
            int pid = rand() % NUM_ACTIVE_PROGRAMS;
			for(int n = 0; ctxt[idx].is_active && n < MAX_CONCURRENT; idx = (idx + 1) % MAX_CONCURRENT, n++);
			if(ctxt[idx].is_active) {
				rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MAIN] context buffer full!\n");
			} else {
				activate_application(&ctxt[idx], active_programs, pid, fid);
				ctrl_config.num_active++;
				fid++;
				idx = (idx + 1) % MAX_CONCURRENT;
			}
        }

		rte_delay_ms(ARRIVAL_DELAY_MS);
	}

	is_running = 0;

	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MAIN] experiment complete.\n");

	rte_eal_cleanup();

	return 0;
}
