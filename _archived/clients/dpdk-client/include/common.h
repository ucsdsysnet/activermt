#ifndef COMMON_H
#define COMMON_H

#include <assert.h>
#include <stdio.h>
#include <signal.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>

#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_cycles.h>
#include <rte_lcore.h>
#include <rte_mbuf.h>
#include <rte_mbuf_dyn.h>
#include <rte_compat.h>
#include <rte_memory.h>
#include <rte_malloc.h>
#include <rte_log.h>

#include "types.h"
#include "utils.h"
#include "active.h"
#include "memory.h"
#include "control.h"
#include "encap.h"
#include "decap.h"

#include "../../../headers/activep4.h"

#define DEBUG_COMMON

#define MAX_TX_BUFS 1024
#define ACTIVE_FOREACH_APP(app_id, ctxt) for(app_id = 0, ctxt = &ap4_ctxt[app_id]; app_id < cfg.num_apps; app_id++, ctxt = &ap4_ctxt[app_id])

static pnemonic_opcode_t instr_set;
static active_apps_t apps_ctxt;
static activep4_context_t* ap4_ctxt;
static active_control_t ctrl;
static active_config_t cfg;

static void 
interrupt_handler(int sig) {
    is_running = 0;
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
			rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Error during getting device (port %u)\n", port);
			exit(EXIT_FAILURE);
		}
		if(strcmp(dev_info.driver_name, "net_virtio_user") == 0) {
			vdev[port] = 1;
		}
		if(rte_eth_dev_socket_id(port) > 0 && rte_eth_dev_socket_id(port) != (int)rte_socket_id()) {
			printf("WARNING, port %u is on remote NUMA node to polling thread.\n\tPerformance will not be optimal.\n", port);
		}
		else {
			rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d on local NUMA node.\n", port);
		}
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d Queues RX %d Tx %d\n", port, dev_info.nb_rx_queues, dev_info.nb_tx_queues);
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
			/*rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[PORT %d][RX] %d pkts.\n", port, nb_rx);
			for(int i = 0; i < nb_rx; i++) {
				char* pkt = rte_pktmbuf_mtod(bufs[i], char*);
				print_pktinfo(pkt, bufs[i]->pkt_len);
			}*/
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

static inline int
port_init(uint16_t port, struct rte_mempool *mbuf_pool, active_apps_t* apps_ctxt)
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

	// const uint16_t rx_rings = (dev_info.max_rx_queues > 3) ? 4 : 1;
	const uint16_t rx_rings = NUM_RX_QUEUES;
	#ifdef CTRL_MULTICORE
	const uint16_t tx_rings = (dev_info.max_tx_queues > apps_ctxt->num_apps) ? apps_ctxt->num_apps + 1 : 1;
	#else
	const uint16_t tx_rings = (dev_info.max_tx_queues > NUM_TX_QUEUES) ? NUM_TX_QUEUES : dev_info.max_tx_queues;
	#endif

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

void 
active_client_init(char* config_filename, char* active_programs_config_filename, char* dev, char* instr_set_path) {

	is_running = 1;
	signal(SIGINT, interrupt_handler);

    // Initialize log.
    FILE *logfd = fopen("rte_log_activep4.log", "w");
	if(logfd == NULL || rte_openlog_stream(logfd) < 0) {
		rte_exit(EXIT_FAILURE, "Unable to create log file!");
	} else {
		rte_log_register_type_and_pick_level("AP4", RTE_LOG_INFO);
	}

	memset(&cfg, 0, sizeof(active_config_t));

	// Read active program configurations.
	read_active_program_config(active_programs_config_filename, &cfg);
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Read configurations for %d programs.\n", cfg.num_programs);

    // Read application configurations.
	read_activep4_config(config_filename, &cfg);
	if(cfg.num_apps > MAX_APPS) cfg.num_apps = MAX_APPS;
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Read configurations for %d apps.\n", cfg.num_apps);

    // Get interface address.
    uint32_t ipv4_ifaceaddr = get_iface_ipv4_addr(dev);
	char ip_addr_str[16];
	inet_ntop(AF_INET, &ipv4_ifaceaddr, ip_addr_str, 16);
	printf("Interface %s has IPv4 address %s\n", dev, ip_addr_str);

    // Allocate context data structures.
	memset(&instr_set, 0, sizeof(pnemonic_opcode_t));
	activep4_def_t* active_function = (activep4_def_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(activep4_def_t), 0);
	if(active_function == NULL) {
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Unable to allocate memory for active function!\n");
		exit(EXIT_FAILURE);
	}
	ap4_ctxt = (activep4_context_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(activep4_context_t), 0);
	if(ap4_ctxt == NULL) {
		rte_exit(EXIT_FAILURE, "Unable to allocate memory for active context!\n");
	}
	active_app_stats_t* app_stats = (active_app_stats_t*)rte_zmalloc(NULL, MAX_APPS * sizeof(active_app_stats_t), 0);
	if(app_stats == NULL) {
		rte_exit(EXIT_FAILURE, "Unable to allocate memory for active stats!\n");
	}
	memset(&apps_ctxt, 0, sizeof(active_apps_t));

    uint64_t ts_ref = rte_rdtsc_precise();

	read_opcode_action_map(instr_set_path, &instr_set);

	// read active program definitions.
	for(int i = 0; i < cfg.num_programs; i++) {
		char* active_dir = cfg.active_programs[i].program_path;
		char* active_program_name = cfg.active_programs[i].program_name;
		read_active_function(&active_function[i], active_dir, active_program_name);
		strcpy(active_function[i].name, cfg.active_programs[i].program_name);
	}

	int current_fid = 1;

	// read active application definitions.
	for(int i = 0; i < cfg.num_apps; i++) {

		int current_pid = 0;

		app_stats[i].ts_ref = ts_ref;
		ap4_ctxt[i].instr_set = &instr_set;

		ap4_ctxt[i].num_programs = cfg.active_apps[i].num_functions;
		assert(ap4_ctxt[i].num_programs > 0);

		ap4_ctxt[i].fid = current_fid++;
		ap4_ctxt[i].current_pid = current_pid;

		// assign active functions to applications.
		for(int j = 0; j < cfg.active_apps[i].num_functions; j++) {
			ap4_ctxt[i].programs[j] = rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
			ap4_ctxt[i].programs[j]->pid = current_pid++;
			for(int k = 0; k < cfg.num_programs; k++) {
				if(strcmp(cfg.active_apps[i].functions[j]->program_name, cfg.active_programs[k].program_name) == 0) {
					rte_memcpy(ap4_ctxt[i].programs[j], &active_function[k], sizeof(activep4_def_t));
					rte_memcpy(ap4_ctxt[i].programs[j]->mutant.code, active_function[k].code, sizeof(active_function[k].code));
					ap4_ctxt[i].programs[j]->mutant.proglen = active_function[k].proglen;
					break;
				}
			}
		}

		ap4_ctxt[i].active_tx_enabled = true;
		ap4_ctxt[i].active_heartbeat_enabled = true;
		ap4_ctxt[i].active_timer_enabled = false;
		ap4_ctxt[i].timer_interval_us = DEFAULT_TI_US;
		ap4_ctxt[i].is_active = false;
		ap4_ctxt[i].is_elastic = true;
		ap4_ctxt[i].status = ACTIVE_STATE_INITIALIZING;
		ap4_ctxt[i].ipv4_srcaddr = ipv4_ifaceaddr;
		
		apps_ctxt.app_id[i] = cfg.active_apps[i].app_id;

		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "ActiveP4 context initialized with defaults for %s FID %d.\n", cfg.active_apps[i].appname, ap4_ctxt[i].fid);
	}

    apps_ctxt.ctxt = ap4_ctxt;
	apps_ctxt.stats = app_stats;
	apps_ctxt.num_apps = cfg.num_apps;

	memset(&ctrl, 0, sizeof(active_control_t));
	ctrl.apps_ctxt = &apps_ctxt;

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

	#ifdef CTRL_MULTICORE
	for(int i = 0; i < cfg.num_apps; i++) {
		tx_buffers[i] = (struct rte_eth_dev_tx_buffer*)rte_zmalloc(NULL, RTE_ETH_TX_BUFFER_SIZE(BURST_SIZE), 0);
		if(tx_buffers[i] == NULL)
			rte_exit(EXIT_FAILURE, "Cannot allocate TX buffer for control thread.");
		if(rte_eth_tx_buffer_init(tx_buffers[i], BURST_SIZE) != 0)
			rte_exit(EXIT_FAILURE, "Cannot initialize TX buffer for control thread.");
		if(rte_eth_tx_buffer_set_err_callback(tx_buffers[i], rte_eth_tx_buffer_count_callback, &drop_counter) < 0)
			rte_exit(EXIT_FAILURE, "Cannot set error callback for TX buffer for control thread.");
	}
	#else
	buffer = (struct rte_eth_dev_tx_buffer*)rte_zmalloc(NULL, RTE_ETH_TX_BUFFER_SIZE(BURST_SIZE), 0);
	if(buffer == NULL)
		rte_exit(EXIT_FAILURE, "Cannot allocate TX buffer for control thread.");
	if(rte_eth_tx_buffer_init(buffer, BURST_SIZE) != 0)
		rte_exit(EXIT_FAILURE, "Cannot initialize TX buffer for control thread.");
	if(rte_eth_tx_buffer_set_err_callback(buffer, rte_eth_tx_buffer_count_callback, &drop_counter) < 0)
		rte_exit(EXIT_FAILURE, "Cannot set error callback for TX buffer for control thread.");
	#endif

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

	printf("Main thread running on lcore %d socket %d\n", rte_lcore_id(), rte_lcore_to_socket_id(rte_lcore_id()));

	unsigned lcore_id = rte_get_next_lcore(rte_lcore_id(), 1, 0);

	int ports[RTE_MAX_ETHPORTS];
	RTE_ETH_FOREACH_DEV(portid) {
		ports[portid] = portid;
		if(port_init(portid, mbuf_pool, &apps_ctxt) != 0)
			rte_exit(EXIT_FAILURE, "Cannot init port %"PRIu16"\n", portid);
		#ifdef STATS
		rte_eal_remote_launch(lcore_stats, (void*)&ports[portid], lcore_id);
		#endif
	}

	#ifdef CTRL_MULTICORE
	active_control_app_t ctrlapp[MAX_APPS];
	for(int i = 0; i < cfg.num_apps; i++) {
		ctrlapp[i].app_id = i;
		ctrlapp[i].ctrl = &ctrl;
	}
	for(int i = 0; i < cfg.num_apps; i++) {
		lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
		rte_eal_remote_launch(lcore_control, (void*)&ctrlapp[i], lcore_id);
	}
	#else
	printf("Launching control thread ... \n");
	lcore_id = rte_get_next_lcore(lcore_id, 1, 0);
	if(rte_eal_remote_launch(lcore_control, (void*)&ctrl, lcore_id) != 0) {
		rte_exit(EXIT_FAILURE, "Failed to launch controller on lcore %d\n", lcore_id);
	}
	#endif
}

void 
active_client_shutdown() {

    for(int i = 0; i < apps_ctxt.num_apps; i++) {
		apps_ctxt.ctxt[i].shutdown(i, apps_ctxt.ctxt[i].app_context);
	}

	write_active_tx_stats(&apps_ctxt);
}

#endif