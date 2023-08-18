/**
 * @file main.c
 * @author Rajdeep Das (r4das@ucsd.edu)
 * @brief 
 * @version 1.0
 * @date 2023-08-18
 * 
 * @copyright Copyright (c) 2023 Rajdeep Das, University of California San Diego.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 */

#include <signal.h>
#include <rte_malloc.h>

#include "../../../../include/c/dpdk/types.h"
#include "../../../../include/c/dpdk/utils.h"
#include "../../../../include/c/dpdk/memory.h"
#include "../../../../include/c/dpdk/active.h"

#include "ping.h"
#include "rx.h"
#include "tx.h"

#define DEBUG_PING

#define INSTR_SET_PATH		    "../../../../activermt/opcode_action_mapping.csv"
#define ACTIVE_DIR              "../../activesrc"
#define ACTIVE_PROGRAM    		"ping"
#define NUM_ACTIVE_PROGRAMS     1

static void 
interrupt_handler(int sig) {
    is_running = 0;
}

static void
print_usage(char** argv) {
    rte_exit(EXIT_FAILURE, "Usage: %s\n", argv[0]);
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

    if(num_instances <= 0) print_usage(argv);

	int ret = rte_eal_init(argc, argv);
	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

    is_running = 1;
	signal(SIGINT, interrupt_handler);

    FILE *logfd = fopen("rte_log_active_ping.log", "w");
	if(logfd == NULL || rte_openlog_stream(logfd) < 0) {
		rte_exit(EXIT_FAILURE, "Unable to create log file!");
	} else {
		rte_log_register_type_and_pick_level("AP4", RTE_LOG_INFO);
	}

    pnemonic_opcode_t instr_set;
    memset(&instr_set, 0, sizeof(pnemonic_opcode_t));
    read_opcode_action_map(INSTR_SET_PATH, &instr_set);

    activep4_context_t* ctxt = (activep4_context_t*)rte_zmalloc(NULL, sizeof(activep4_context_t), 0);
	if(ctxt == NULL) {
		rte_exit(EXIT_FAILURE, "Unable to allocate memory for active context!\n");
	}

    ping_context_t* ping = (ping_context_t*)rte_zmalloc(NULL, num_instances * sizeof(ping_context_t), 0);
    if(ping == NULL) {
		rte_exit(EXIT_FAILURE, "Unable to allocate memory for ping context!\n");
	}

    activep4_def_t* active_program = (activep4_def_t*)rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
    if(active_program == NULL) {
        rte_exit(EXIT_FAILURE, "Unable to allocate memory for active programs!\n");
    }

    read_active_function(active_program, ACTIVE_DIR, ACTIVE_PROGRAM);
    strcpy(active_program->name, ACTIVE_PROGRAM);

    for(int i = 0; i < num_instances; i++) {

		ctxt[i].instr_set = &instr_set;

		ctxt[i].num_programs = NUM_ACTIVE_PROGRAMS;
		assert(ctxt[i].num_programs > 0);

		ctxt[i].fid = i + 1;
		ctxt[i].current_pid = 0;

		for(int j = 0; j < NUM_ACTIVE_PROGRAMS; j++) {
			ctxt[i].programs[j] = rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
			ctxt[i].programs[j]->pid = j;
			rte_memcpy(ctxt[i].programs[j], active_program, sizeof(activep4_def_t));
			rte_memcpy(ctxt[i].programs[j]->mutant.code, active_program->code, sizeof(active_program->code));
			ctxt[i].programs[j]->mutant.proglen = active_program->proglen;
		}

		ctxt[i].active_tx_enabled = true;
		ctxt[i].active_heartbeat_enabled = false;
		ctxt[i].active_timer_enabled = true;
		ctxt[i].timer_interval_us = 1000000;
		ctxt[i].is_active = true;
		ctxt[i].is_elastic = false;
		ctxt[i].status = ACTIVE_STATE_TRANSMITTING;
		ctxt[i].ipv4_srcaddr = APP_IPV4_ADDR;

        ctxt[i].app_context = (void*)&ping[i];

        ctxt[i].shutdown = shutdown_ping;

		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] ActiveP4 context initialized with programs:\n", ctxt[i].fid);
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] 1. %s\n", ctxt[i].fid, active_program->name);
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

    memset(rx_config, 0, sizeof(rx_config));
    memset(tx_config, 0, sizeof(tx_config));

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
        rx_config[portid].ctxt = ctxt;
        rx_config[portid].num_instances = num_instances;
        rx_config[portid].port_id = portid;
        lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
        assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
        rte_eal_remote_launch(lcore_rx, (void*)&rx_config[portid], lcore_id);
        tx_config[portid].ctxt = ctxt;
        tx_config[portid].num_instances = num_instances;
        tx_config[portid].num_active = num_instances;
        tx_config[portid].port_id = portid;
        lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
        assert(rte_lcore_to_socket_id(lcore_id) == rte_socket_id());
        rte_eal_remote_launch(lcore_tx, (void*)&tx_config[portid], lcore_id);
	}

	rte_eal_cleanup();

	return 0;
}
