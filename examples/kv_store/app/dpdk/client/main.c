#include <signal.h>
#include <rte_malloc.h>

#include "../../../../../include/c/dpdk/types.h"
#include "../../../../../include/c/dpdk/utils.h"
#include "../../../../../include/c/dpdk/memory.h"
#include "../../../../../include/c/dpdk/active.h"

#include "cache.h"
#include "monitor.h"
#include "rx.h"
#include "tx.h"
#include "control.h"
#include "common.h"

#define DEBUG_CACHE
// #define MODULAR

#define KEYDIST_PATH            "zipf_dist_a_1.1_n_100000.csv"
#define INSTR_SET_PATH		    "../../../../../activermt/opcode_action_mapping.csv"
#define ACTIVE_DIR              "../../../activesrc"
#define ACTIVE_PROGRAM_CACHE    "kvstore"
#define ACTIVE_PROGRAM_MONITOR	"hh"

#define APP_IPV4_ADDR       0x0100000a
#define APP_IPV4_DSTADDR    0x0100000a
#define NUM_ACTIVE_PROGRAMS 2
#define PORT_START			5678
#define DEMAND_HH			128

void
context_switch_cache(activep4_context_t* ctxt) {
	ctxt->memory_consume = memory_consume_cache;
	ctxt->memory_invalidate = memory_invalidate_cache;
	ctxt->memory_reset = memory_reset_cache;
	ctxt->timer = timer_cache;
	ctxt->on_allocation = on_allocation_cache;
	ctxt->timer_interval_us = HH_ITVL_MIN_MS * 1E3;
	ctxt->current_pid = PID_CACHEREAD;
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] context switched to program %s\n", ctxt->fid, ctxt->programs[ctxt->current_pid]->name);
}

void
context_switch_monitor(activep4_context_t* ctxt) {
	ctxt->memory_consume = memory_consume_monitor;
	ctxt->memory_invalidate = memory_invalidate_monitor;
	ctxt->memory_reset = memory_reset_monitor;
	ctxt->timer = timer_monitor;
	ctxt->on_allocation = NULL;
	ctxt->current_pid = PID_FREQITEM;
	int demand[NUM_STAGES];
	memset(demand, DEMAND_HH, NUM_STAGES * sizeof(int));
	set_memory_demand_per_stage(ctxt, demand);
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] context switched to program %s\n", ctxt->fid, ctxt->programs[ctxt->current_pid]->name);
}

static void 
interrupt_handler(int sig) {
    is_running = 0;
}

static void
print_usage(char** argv) {
    rte_exit(EXIT_FAILURE, "Usage: %s [num_instances=1]\n", argv[0]);
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
	int num_instances = (argc > 1) ? atoi(argv[1]) : 1;
	int stagger_interval_sec = (argc > 2) ? atoi(argv[2]) : 0;

    if(num_instances <= 0) print_usage(argv);

	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

    is_running = 1;
	signal(SIGINT, interrupt_handler);

    FILE *logfd = fopen("rte_log_active_cache.log", "w");
	if(logfd == NULL || rte_openlog_stream(logfd) < 0) {
		rte_exit(EXIT_FAILURE, "Unable to create log file!");
	} else {
		rte_log_register_type_and_pick_level("AP4", RTE_LOG_INFO);
	}

    pnemonic_opcode_t instr_set;
    memset(&instr_set, 0, sizeof(pnemonic_opcode_t));
    read_opcode_action_map(INSTR_SET_PATH, &instr_set);

    uint64_t* keydist = (uint64_t*)rte_zmalloc(NULL, MAX_CACHE_SIZE * sizeof(uint64_t), 0);
    int keydist_size = 0;

    read_key_dist(KEYDIST_PATH, keydist, &keydist_size);

    activep4_context_t* ctxt = (activep4_context_t*)rte_zmalloc(NULL, num_instances * sizeof(activep4_context_t), 0);
	if(ctxt == NULL) {
		rte_exit(EXIT_FAILURE, "Unable to allocate memory for active context!\n");
	}

    cache_context_t* cache = (cache_context_t*)rte_zmalloc(NULL, num_instances * sizeof(cache_context_t), 0);
    if(cache == NULL) {
		rte_exit(EXIT_FAILURE, "Unable to allocate memory for cache context!\n");
	}

    activep4_def_t* active_programs = (activep4_def_t*)rte_zmalloc(NULL, NUM_ACTIVE_PROGRAMS * sizeof(activep4_def_t), 0);
    if(active_programs == NULL) {
        rte_exit(EXIT_FAILURE, "Unable to allocate memory for active programs!\n");
    }

    read_active_function(&active_programs[PID_CACHEREAD], ACTIVE_DIR, ACTIVE_PROGRAM_CACHE);
    strcpy(active_programs[PID_CACHEREAD].name, ACTIVE_PROGRAM_CACHE);

	read_active_function(&active_programs[PID_FREQITEM], ACTIVE_DIR, ACTIVE_PROGRAM_MONITOR);
    strcpy(active_programs[PID_FREQITEM].name, ACTIVE_PROGRAM_MONITOR);

    uint64_t ts_ref = rte_rdtsc_precise();

    for(int i = 0; i < num_instances; i++) {

        cache[i].keydist = keydist;
        cache[i].distsize = keydist_size;
        cache[i].ts_ref = ts_ref;
		cache[i].ipv4_dstaddr = APP_IPV4_DSTADDR;
		cache[i].app_port = PORT_START + i;
		#ifdef MODULAR
		cache[i].frequent_item_monitor = 1;
		#else
		cache[i].frequent_item_monitor = 0;
		#endif

		ctxt[i].instr_set = &instr_set;

		ctxt[i].num_programs = NUM_ACTIVE_PROGRAMS;
		assert(ctxt[i].num_programs > 0);

		ctxt[i].fid = i + 1;
		#ifdef MODULAR
		ctxt[i].current_pid = PID_FREQITEM;
		#else
		ctxt[i].current_pid = PID_CACHEREAD;
		#endif

		for(int j = 0; j < NUM_ACTIVE_PROGRAMS; j++) {
			ctxt[i].programs[j] = rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
			ctxt[i].programs[j]->pid = j;
			rte_memcpy(ctxt[i].programs[j], &active_programs[j], sizeof(activep4_def_t));
			rte_memcpy(ctxt[i].programs[j]->mutant.code, active_programs[j].code, sizeof(active_programs[j].code));
			ctxt[i].programs[j]->mutant.proglen = active_programs[j].proglen;
		}

		ctxt[i].active_tx_enabled = true;
		ctxt[i].active_heartbeat_enabled = true;
		ctxt[i].active_timer_enabled = true;
		#ifdef MODULAR
		ctxt[i].timer_interval_us = 2 * DEFAULT_TI_US;
		#else
		ctxt[i].timer_interval_us = 100;
		#endif
		ctxt[i].is_active = false;
		ctxt[i].is_elastic = true;
		ctxt[i].status = ACTIVE_STATE_INITIALIZING;
		ctxt[i].ipv4_srcaddr = APP_IPV4_ADDR;

        ctxt[i].app_context = (void*)&cache[i];

        ctxt[i].shutdown = shutdown_cache;
		#ifdef MODULAR
		context_switch_monitor(&ctxt[i]);
		#else
		context_switch_cache(&ctxt[i]);
		#endif

		// TODO debug
		// int memsize = 65536;
		// activep4_def_t* prog = ctxt[i].programs[PID_FREQITEM];
		// for(int j = 0; j < prog->num_accesses; j++) {
		// 	ctxt[i].allocation.valid_stages[prog->access_idx[i]] = 1;
		// 	ctxt[i].allocation.sync_data[prog->access_idx[i]].mem_start = 0;
		// 	ctxt[i].allocation.sync_data[prog->access_idx[i]].mem_end = memsize - 1;
		// }
		// cache[i].memory_start = 0;
		// cache[i].memory_size = memsize;

		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] ActiveP4 context initialized with programs:\n", ctxt[i].fid);
		for(int j = 0; j < NUM_ACTIVE_PROGRAMS; j++) {
			rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] %d. %s\n", ctxt[i].fid, j + 1, active_programs[j].name);
		}
	}

    uint16_t nb_ports;
	uint16_t portid;

	nb_ports = rte_eth_dev_count_avail();
	if (nb_ports > 1)
		rte_exit(EXIT_FAILURE, "Error: at most one port is required.\n");

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

    rx_config_t rx_config[RTE_MAX_ETHPORTS];
    tx_config_t tx_config[RTE_MAX_ETHPORTS];
    control_config_t ctrl_config[RTE_MAX_ETHPORTS];

    memset(rx_config, 0, sizeof(rx_config));
    memset(tx_config, 0, sizeof(tx_config));
    memset(ctrl_config, 0, sizeof(ctrl_config));

    unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);
    assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());

    int ports[RTE_MAX_ETHPORTS];
	RTE_ETH_FOREACH_DEV(portid) {
		ports[portid] = portid;
		if(port_init(portid, mbuf_pool) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);
		#ifdef STATS
		rte_eal_remote_launch(lcore_stats, (void*)&ports[portid], lcore_id);
		#endif
        lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
        assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
        ctrl_config[portid].ctxt = ctxt;
        ctrl_config[portid].num_instances = num_instances;
        ctrl_config[portid].port_id = portid;
        rte_eal_remote_launch(lcore_control, (void*)&ctrl_config[portid], lcore_id);
        rx_config[portid].ctxt = ctxt;
        rx_config[portid].num_instances = num_instances;
        rx_config[portid].port_id = portid;
        lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
        assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
        rte_eal_remote_launch(lcore_rx, (void*)&rx_config[portid], lcore_id);
        tx_config[portid].ctxt = ctxt;
        tx_config[portid].num_instances = num_instances;
        tx_config[portid].num_active = 0;
        tx_config[portid].port_id = portid;
        lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
        assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
        rte_eal_remote_launch(lcore_tx, (void*)&tx_config[portid], lcore_id);
	}

    for(int i = 0; i < num_instances; i++) {
        ctxt[i].is_active = true;
		RTE_ETH_FOREACH_DEV(portid) {
			tx_config[portid].num_active++;
		}
        rte_delay_ms(stagger_interval_sec * 1E3);
    }

	rte_eal_cleanup();

	return 0;
}
