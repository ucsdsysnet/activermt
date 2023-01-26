// #define DEBUG
// #define PDUMP_ENABLE

#define INSTR_SET_PATH		"../../config/opcode_action_mapping.csv"

#include "active_cache.h"
#include "active_hh.h"
#include "active_lb.h"

int
main(int argc, char** argv)
{
	if(argc < 4) {
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Usage: %s <iface> <config_file> <program_config_filename>\n", argv[0]);
		exit(EXIT_FAILURE);
	}

	char* dev = argv[1];
	char* config_filename = argv[2];
	char* programs_config_filename = argv[3];

	int ret = rte_eal_init(argc, argv);

	if (ret < 0)
		rte_exit(EXIT_FAILURE, "Error with EAL initialization\n");
	argc -= ret;
	argv += ret;

	active_client_init(config_filename, programs_config_filename, dev, INSTR_SET_PATH);

	uint64_t ts_ref = rte_rdtsc_precise();

	activep4_context_t* ctxt;
	int app_id;
	ACTIVE_FOREACH_APP(app_id, ctxt) {
		int initialized = 0;
		if(strcmp(cfg.active_apps[app_id].appname, "cache") == 0) {
			// socket application: custom udp client sending kv requests.
			printf("Initializing app %d (%s) ...\n", app_id, cfg.active_apps[app_id].appname);
			ctxt->app_context = rte_zmalloc(NULL, sizeof(cache_context_t), 0);
			assert(ctxt->app_context != NULL);
			((cache_context_t*)ctxt->app_context)->ts_ref = ts_ref;
			ctxt->tx_mux = tx_mux_cache;
			ctxt->tx_handler = payload_parser_cache;
			ctxt->rx_handler = active_rx_handler_cache;
			ctxt->memory_consume = memory_consume_cache;
			ctxt->memory_invalidate = memory_invalidate_cache;
			ctxt->memory_reset = memory_reset_cache;
			ctxt->shutdown = shutdown_cache;
			ctxt->timer = timer_cache;
			ctxt->active_heartbeat_enabled = true;
			initialized = 1;
			printf("Functions:\n");
			for(int k = 0; k < ctxt->num_programs; k++) {
				printf("%d. %s\n", k + 1, cfg.active_apps[app_id].functions[k]->program_name);
			}
		} else if(strcmp(cfg.active_apps[app_id].appname, "hh") == 0) {
			// socket application: custom udp client sending kv requests.
			printf("Initializing app %d (%s) ...\n", app_id, cfg.active_apps[app_id].appname);
			ctxt->app_context = rte_zmalloc(NULL, sizeof(hh_context_t), 0);
			assert(ctxt->app_context != NULL);
			ctxt->tx_mux = tx_mux_hh;
			ctxt->tx_handler = active_tx_handler_hh;
			ctxt->rx_handler = active_rx_handler_hh;
			ctxt->memory_consume = memory_consume_hh;
			ctxt->memory_invalidate = memory_invalidate_hh;
			ctxt->memory_reset = memory_reset_hh;
			ctxt->shutdown = shutdown_hh;
			ctxt->timer = timer_hh;
			ctxt->timer_interval_us = 1000000;
			ctxt->active_tx_enabled = true;
			ctxt->active_timer_enabled = true;
			ctxt->active_heartbeat_enabled = true;
			#ifdef DEBUG
			// static_allocation(&ctxt->allocation);
			// ctxt->status = ACTIVE_STATE_TRANSMITTING;
			#endif
			initialized = 1;
		} else if(strcmp(cfg.active_apps[app_id].appname, "lb") == 0) {
			printf("Initializing app %d (%s) ...\n", app_id, cfg.active_apps[app_id].appname);
			ctxt->app_context = rte_zmalloc(NULL, sizeof(lb_context_t), 0);
			assert(ctxt->app_context != NULL);
			ctxt->tx_mux = active_tx_mux_lb;
			ctxt->tx_handler = active_tx_handler_lb;
			ctxt->rx_handler = active_rx_handler_lb;
			ctxt->memory_consume = memory_consume_lb;
			ctxt->memory_invalidate = memory_invalidate_lb;
			ctxt->memory_reset = memory_reset_lb;
			ctxt->shutdown = shutdown_lb;
			ctxt->timer = timer_lb;
			ctxt->active_heartbeat_enabled = true;
			// DEBUG code
			// static_allocation_lb(&ctxt->allocation);
			// ctxt->status = ACTIVE_STATE_TRANSMITTING;
			// set_memory_demand(ctxt, 2);
			initialized = 1;
			printf("Functions:\n");
			for(int k = 0; k < ctxt->num_programs; k++) {
				printf("%d. %s\n", k + 1, cfg.active_apps[app_id].functions[k]->program_name);
			}
		} else {
			printf("Error: unknown application (%s) in config!\n", cfg.active_apps[app_id].appname);
		}
		assert(initialized == 1);
	}

	#ifdef PDUMP_ENABLE
	if(rte_pdump_init() < 0) {
		rte_exit(EXIT_FAILURE, "Unable to initialize packet capture.");
	}
	#endif

	lcore_main();

	active_client_shutdown();

	rte_eal_cleanup();

	return 0;
}
