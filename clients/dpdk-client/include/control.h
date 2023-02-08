#ifndef CONTROL_H
#define CONTROL_H

#include <rte_ethdev.h>
#include <rte_mbuf.h>
#include <rte_lcore.h>
#include <rte_log.h>

#include "types.h"
#include "utils.h"
#include "active.h"
#include "memory.h"

#include "../../../headers/activep4.h"

static int
lcore_control(void* arg) {

	unsigned lcore_id = rte_lcore_id();

	#ifdef CTRL_MULTICORE
	active_control_app_t* ctrlapp = (active_control_app_t*)arg;
	active_control_t* ctrl = (active_control_t*)ctrlapp->ctrl;
	activep4_context_t* ctxt = &ctrl->apps_ctxt->ctxt[ctrlapp->app_id];
	#else
	active_control_t* ctrl = (active_control_t*)arg;
	#endif

	#ifdef CTRL_MULTICORE
	struct rte_eth_dev_tx_buffer* buffer = tx_buffers[ctrlapp->app_id];
	const int qid = ctrlapp->app_id + 1;
	#else
	const int qid = 1;
	#endif

	#ifdef CTRL_MULTICORE
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Starting controller for port %d on lcore %u app %d ... \n", PORT_PETH, lcore_id, ctrlapp->app_id);
	#else
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Starting controller for port %d on lcore %u (socket %d) ... \n", ctrl->port_id, lcore_id, rte_socket_id());
	#endif

	activep4_def_t memsync_cache[NUM_STAGES], memset_cache[NUM_STAGES];
	memset(memsync_cache, 0, NUM_STAGES * sizeof(activep4_def_t));
	memset(memset_cache, 0, NUM_STAGES * sizeof(activep4_def_t));

	uint64_t now, elapsed_us;
	int snapshotting_in_progress = 0, remapping_in_progress = 0, invalidating_in_progress = 0;

	char tmpbuf[100];

	struct rte_mempool* mempool = NULL;

	mempool = rte_pktmbuf_pool_create(
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

	while(is_running) {
		now = rte_rdtsc_precise();
		#ifndef CTRL_MULTICORE
		for(int i = 0; i < ctrl->apps_ctxt->num_apps; i++) {
			activep4_context_t* ctxt = &ctrl->apps_ctxt->ctxt[i];
			// active_control_state_t* ctrlstat = &ctrl->apps_ctxt->ctrl_status[i];
		#endif
			elapsed_us = (double)(now - ctxt->ctrl_ts_lastsent) * 1E6 / rte_get_tsc_hz();
			if(!ctxt->is_active) continue;
			struct rte_mbuf* mbuf = NULL;
			switch(ctxt->status) {
				case ACTIVE_STATE_INITIALIZING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					ctxt->telemetry.is_initializing = 1;
					if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
						construct_reqalloc_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
						telemetry_allocation_start(ctxt);
					}
					#ifdef DEBUG
					//rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Initializing ... \n");
					#endif
					break;
				case ACTIVE_STATE_REALLOCATING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					/*struct rte_mbuf* mbufs[2];
					if(rte_pktmbuf_alloc_bulk(mempool, mbufs, 2) == 0) {
						construct_getalloc_packet(mbufs[0], ctrl->port_id, ctxt);
						construct_snapshot_packet(mbufs[1], ctrl->port_id, ctxt, 0, 0, NULL, true);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbufs[0]);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbufs[1]);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
						telemetry_allocation_start(ctxt);
					}*/
					if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
						// construct_reallocate_packet(mbuf, ctrl->port_id, ctxt);
						construct_getalloc_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
						telemetry_allocation_start(ctxt);
					}
					if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
						construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, 0, 0, NULL, true);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
					}
					break;
				case ACTIVE_STATE_ALLOCATING:
					if(elapsed_us < CTRL_SEND_INTVL_US) continue;
					if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
						construct_getalloc_packet(mbuf, ctrl->port_id, ctxt);
						rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						ctxt->ctrl_ts_lastsent = now;
						telemetry_allocation_start(ctxt);
					}
					break;
				case ACTIVE_STATE_SNAPSHOTTING:
					#ifdef CTRL_PARALLEL
					if(ctrlstat->snapshotting_in_progress) {
						int sent = 0;
						for(int i = 0; i < NUM_STAGES; i++) {
							if(!ctxt->allocation.valid_stages[i] || !ctxt->allocation.syncmap[i]) continue;
							for(int j = ctxt->allocation.sync_data[i].mem_start; j <= ctxt->allocation.sync_data[i].mem_end; j++) {
								if(ctxt->allocation.sync_data[i].valid[j]) continue;
								if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
									construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, i, j, memsync_cache, false);
									rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
									sent++;
									ctrlstat->counter++;
									// printf("[SNAPSHOT] stage %d index %d \n", i, j);
								}
							}
						}
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						if(sent == 0) {
							ctxt->allocation.sync_end_time = rte_rdtsc_precise();
							consume_memory_objects(&ctxt->allocation, ctxt);
							uint64_t snapshot_time_ns = (double)(ctxt->allocation.sync_end_time - ctxt->allocation.sync_start_time) * 1E9 / rte_get_tsc_hz();
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Snapshot complete after %lu ns, %u packets sent.\n", ctxt->fid, snapshot_time_ns, ctrlstat->counter);
							ctrlstat->snapshotting_in_progress = 0;
							ctrlstat->counter = 0;
							if(ctxt->memory_invalidate(&ctxt->allocation, ctxt)) {
								get_rw_stages_str(ctxt, tmpbuf);
								rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] invalidating memory stages %s... \n", ctxt->fid, tmpbuf);
								ctrlstat->invalidating_in_progress = 1;
							} else {
								rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] skipping invalidation ...\n", ctxt->fid);
								if(ctxt->allocation.invalid)
									ctxt->status = ACTIVE_STATE_REALLOCATING;
								else
									ctxt->status = ACTIVE_STATE_REMAPPING;
							}
						}
						// alternative.
						/*int stage = get_next_valid_stage(ctxt, ctrlstat);
						int index = get_next_valid_index(ctxt, ctrlstat);
						if(stage < 0 || index < 0) {
							rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
							ctxt->allocation.sync_end_time = rte_rdtsc_precise();
							consume_memory_objects(&ctxt->allocation, ctxt);
							uint64_t snapshot_time_ns = (double)(ctxt->allocation.sync_end_time - ctxt->allocation.sync_start_time) * 1E9 / rte_get_tsc_hz();
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Snapshot complete after %lu ns, %u packets sent.\n", ctxt->fid, snapshot_time_ns, ctrlstat->counter);
							ctrlstat->counter = 0;
							ctrlstat->snapshotting_in_progress = 0;
							if(ctxt->memory_invalidate(&ctxt->allocation, ctxt)) {
								get_rw_stages_str(ctxt, tmpbuf);
								rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] invalidating memory stages %s... \n", ctxt->fid, tmpbuf);
								ctrlstat->invalidating_in_progress = 1;
							} else {
								rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] skipping invalidation ...\n", ctxt->fid);
								if(ctxt->allocation.invalid)
									ctxt->status = ACTIVE_STATE_REALLOCATING;
								else
									ctxt->status = ACTIVE_STATE_REMAPPING;
							}
						} else {
							if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
								construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, ctrlstat->current_stage, ctrlstat->current_index, memsync_cache, false);
								rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
								ctrlstat->counter++;
								// printf("[SNAPSHOT] stage %d index %d \n", i, j);
							}
						}*/
					} else if(ctrlstat->invalidating_in_progress) {
						int stage = get_next_valid_stage(ctxt, ctrlstat);
						int index = get_next_valid_index(ctxt, ctrlstat);
						if(stage < 0 || index < 0) {
							rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] invalidation complete.\n", ctxt->fid);
							ctrlstat->invalidating_in_progress = 0;
							if(ctxt->allocation.invalid)
								ctxt->status = ACTIVE_STATE_REALLOCATING;
							else
								ctxt->status = ACTIVE_STATE_REMAPPING;
						} else {
							if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
								construct_memremap_packet(mbuf, ctrl->port_id, ctxt, ctrlstat->current_stage, ctrlstat->current_index, ctxt->allocation.sync_data[ctrlstat->current_stage].data[ctrlstat->current_index], memset_cache);
								rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
							}
						}
					} else {
						memset(ctrlstat, 0, sizeof(active_control_state_t));
						get_rw_stages_str(ctxt, tmpbuf);
						rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Snapshotting stages %s... \n", ctxt->fid, tmpbuf);
						ctxt->allocation.sync_start_time = rte_rdtsc_precise();
						ctrlstat->snapshotting_in_progress = 1;
					}
					#else
					get_rw_stages_str(ctxt, tmpbuf);
					rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Snapshotting stages %s... \n", ctxt->fid, tmpbuf);
					ctxt->allocation.sync_start_time = rte_rdtsc_precise();
					// sync_memory_region(&ctxt->allocation, ctxt, memsync_cache, ctrl->port_id, mempool);
					snapshotting_in_progress = 1;
					int num_sent = 0;
					while(snapshotting_in_progress) {
						snapshotting_in_progress = 0;
						for(int i = 0; i < NUM_STAGES; i++) {
							if(!ctxt->allocation.valid_stages[i] || !ctxt->allocation.syncmap[i]) continue;
							for(int j = ctxt->allocation.sync_data[i].mem_start; j <= ctxt->allocation.sync_data[i].mem_end; j++) {
								if(ctxt->allocation.sync_data[i].valid[j]) continue;
								snapshotting_in_progress = 1;
								if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
									construct_snapshot_packet(mbuf, ctrl->port_id, ctxt, i, j, memsync_cache, false);
									rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
									num_sent++;
									// printf("[SNAPSHOT] stage %d index %d \n", i, j);
								}
							}
						}
					}
					rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
					ctxt->allocation.sync_end_time = rte_rdtsc_precise();
					consume_memory_objects(&ctxt->allocation, ctxt);
					uint64_t snapshot_time_ns = (double)(ctxt->allocation.sync_end_time - ctxt->allocation.sync_start_time) * 1E9 / rte_get_tsc_hz();
					rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Snapshot complete after %lu ns w/ %d packets\n", ctxt->fid, snapshot_time_ns, num_sent);
					if(ctxt->memory_invalidate(&ctxt->allocation, ctxt)) {
						get_rw_stages_str(ctxt, tmpbuf);
						rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] invalidating memory stages %s... \n", ctxt->fid, tmpbuf);
						invalidating_in_progress = 1;
						while(invalidating_in_progress) {
							invalidating_in_progress = 0;
							for(int i = 0; i < NUM_STAGES; i++) {
								if(!ctxt->allocation.valid_stages[i]) continue;
								for(int j = ctxt->allocation.sync_data[i].mem_start; j <= ctxt->allocation.sync_data[i].mem_end; j++) {
									if(ctxt->allocation.sync_data[i].valid[j] || !ctxt->allocation.syncmap[i]) continue;
									invalidating_in_progress = 1;
									if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
										construct_memremap_packet(mbuf, ctrl->port_id, ctxt, i, j, ctxt->allocation.sync_data[i].data[j], memset_cache);
										rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
									}
								}
							}
						}
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] invalidation complete.\n", ctxt->fid);
					} else {
						rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] skipping invalidation ...\n", ctxt->fid);
					}
					if(ctxt->allocation.invalid)
						ctxt->status = ACTIVE_STATE_REALLOCATING;
					else
						ctxt->status = ACTIVE_STATE_REMAPPING;
					#endif
					break;
				case ACTIVE_STATE_UPDATING:
				case ACTIVE_STATE_REMAPPING:
					remapping_in_progress = 1;
					memory_t* updated_region = &ctxt->membuf;
					updated_region->fid = ctxt->allocation.fid;
					for(int k = 0; k < NUM_STAGES; k++) {
						updated_region->valid_stages[k] = ctxt->allocation.valid_stages[k];
						updated_region->sync_data[k].mem_start = ctxt->allocation.sync_data[k].mem_start;
						updated_region->sync_data[k].mem_end = ctxt->allocation.sync_data[k].mem_end;
					}
					if(reset_memory_region(updated_region, ctxt)) {
						get_rw_stages_str(ctxt, tmpbuf);
						// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Resetting stages %s... \n", ctxt->fid, tmpbuf);
						while(remapping_in_progress) {
							remapping_in_progress = 0;
							for(int i = 0; i < NUM_STAGES; i++) {
								if(!ctxt->allocation.valid_stages[i]) continue;
								for(int j = ctxt->allocation.sync_data[i].mem_start; j <= ctxt->allocation.sync_data[i].mem_end; j++) {
									if(updated_region->sync_data[i].valid[j]) continue;
									snapshotting_in_progress = 1;
									if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
										construct_memremap_packet(mbuf, ctrl->port_id, ctxt, i, j, updated_region->sync_data[i].data[j], memset_cache);
										rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
										// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Sending remap for stage %d index %d data %u ... \n", i, j, updated_region->sync_data[i].data[j]);
									}
								}
							}
						}
						rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
						// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Reset complete.\n", ctxt->fid);
					} else {
						rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] skipping reset ...\n", ctxt->fid);
					}
					ctxt->status = ACTIVE_STATE_TRANSMITTING;
					break;
				case ACTIVE_STATE_TRANSMITTING:
					if(ctxt->active_heartbeat_enabled && elapsed_us >= CTRL_HEARTBEAT_ITVL) {
						if((mbuf = rte_pktmbuf_alloc(mempool)) != NULL) {
							construct_heartbeat_packet(mbuf, ctrl->port_id, ctxt);
							rte_eth_tx_buffer(PORT_PETH, qid, buffer, mbuf);
							rte_eth_tx_buffer_flush(PORT_PETH, qid, buffer);
							ctxt->ctrl_ts_lastsent = now;
						} else {
							rte_exit(EXIT_FAILURE, "Unable to allocate buffer for control packet.");
						}
					}
					elapsed_us = (double)(now - ctxt->ctrl_timer_lasttick) * 1E6 / rte_get_tsc_hz();
					if(ctxt->active_timer_enabled && elapsed_us >= ctxt->timer_interval_us) {
						if(ctxt->timer != NULL) ctxt->timer((void*)ctxt);
						ctxt->ctrl_timer_lasttick = now;
					}
					break;
				default:
					break;
			}
		#ifndef CTRL_MULTICORE
		}
		#endif
	}

	return 0;
}

#endif