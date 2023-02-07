#ifndef RX_H
#define RX_H

#include <rte_ethdev.h>

#include "../../include/types.h"
#include "cache.h"

typedef struct {
    activep4_context_t*     ctxt;
    int                     num_instances;
    int                     port_id;
} rx_config_t;

static int
lcore_rx(void* arg) {

    rx_config_t* cfg = (rx_config_t*)arg;

    int port_id = cfg->port_id;
    int num_instances = cfg->num_instances;
    activep4_context_t* ctxts = cfg->ctxt;

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "RX thread running for port %d on lcore %d\n", port_id, rte_lcore_id());

    struct rte_eth_dev_info dev_info;
    if(rte_eth_dev_info_get(port_id, &dev_info) != 0) {
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Error during getting device (port %u)\n", port_id);
        exit(EXIT_FAILURE);
    }
    if(rte_eth_dev_socket_id(port_id) > 0 && rte_eth_dev_socket_id(port_id) != (int)rte_socket_id()) {
        printf("WARNING, port %u is on remote NUMA node to polling thread.\n\tPerformance will not be optimal.\n", port_id);
    }
    else {
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d on local NUMA node.\n", port_id);
    }
    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d Queues RX %d Tx %d\n", port_id, dev_info.nb_rx_queues, dev_info.nb_tx_queues);

    printf("Ctrl+C to exit ... \n");

    const int qid = 0;

    while(is_running) {
		struct rte_mbuf* bufs[BURST_SIZE];
        const uint16_t nb_rx = rte_eth_rx_burst(port_id, qid, bufs, BURST_SIZE);
        
        if (unlikely(nb_rx == 0))
            continue;

        for(int p = 0; p < nb_rx; p++) {

            char* bufptr = rte_pktmbuf_mtod(bufs[p], char*);

            struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;

            int offset = 0;

            if(ntohs(hdr_eth->ether_type) == RTE_ETHER_TYPE_IPV4) {
			    // TODO unknown packet.
		    } else if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
                
                activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
                if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
                
                uint16_t flags = ntohs(ap4ih->flags);
			    uint16_t fid = ntohs(ap4ih->fid);
                uint16_t seq = ntohs(ap4ih->seq);

                activep4_data_t* ap4data = NULL;
                offset += sizeof(activep4_ih);
                if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
                    ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
                }

                activep4_context_t* ctxt = NULL;
                cache_context_t* cache = NULL;
                for(int i = 0; i < num_instances; i++) {
                    if(fid == ctxts[i].fid) {
                        ctxt = &ctxts[i];
                        cache = (cache_context_t*)ctxt->app_context;
                    }
                }

                if(ctxt == NULL || cache == NULL) continue;

                uint8_t current_state = ctxt->status;

                switch(ctxt->status) {
                    case ACTIVE_STATE_INITIALIZING:
                        if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REQALLOC)) {
                            ctxt->status = ACTIVE_STATE_ALLOCATING;
                        }
                        break;
                    case ACTIVE_STATE_REALLOCATING:
                        // rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] FID %d STATE %d Flags %x\n", ctxt->fid, ctxt->status, flags);
                    case ACTIVE_STATE_ALLOCATING:
                        if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
                            if(ctxt->allocation.version != seq) {
                                ctxt->telemetry.allocation_request_stop_ts = rte_rdtsc_precise();
                                activep4_malloc_res_t* ap4malloc = (activep4_malloc_res_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
                                ctxt->allocation.invalid = 0;
                                ctxt->allocation.version = seq;
                                ctxt->allocation.hash_function = NULL;
                                rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] ALLOCATION (ver %d) ", fid, ctxt->allocation.version);
                                for(int i = 0; i < NUM_STAGES; i++) {
                                    ctxt->allocation.sync_data[i].mem_start = ntohl(ap4malloc->mem_range[i].start);
                                    ctxt->allocation.sync_data[i].mem_end = ntohl(ap4malloc->mem_range[i].end);
                                    if((ctxt->allocation.sync_data[i].mem_end - ctxt->allocation.sync_data[i].mem_start) > 0) {
                                        ctxt->allocation.valid_stages[i] = 1;
                                        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "{S%d: %d - %d} ", i, ctxt->allocation.sync_data[i].mem_start, ctxt->allocation.sync_data[i].mem_end);
                                    }
                                }
                                rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "\n");
                                mutate_active_program(ctxt->programs[ctxt->current_pid], &ctxt->allocation, 1, ctxt->instr_set);
                                ctxt->telemetry.allocation_is_active = 0;
                                ctxt->status = ACTIVE_STATE_REMAPPING;
                                uint64_t allocation_elapsed_ns 
                                    = (double)(ctxt->telemetry.allocation_request_stop_ts - ctxt->telemetry.allocation_request_start_ts) * 1E9 / rte_get_tsc_hz();
                                if(ctxt->telemetry.is_initializing == 1)
                                    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] allocation time %ld ns\n", fid, allocation_elapsed_ns);
                                else
                                    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] reallocation time %ld ns\n", fid, allocation_elapsed_ns);
                                ctxt->telemetry.is_initializing = 0;
                                #ifdef DEBUG
                                rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] state %d\n", ctxt->status);
                                #endif
                            }
                        }
                        break;
                    case ACTIVE_STATE_SNAPSHOTTING:
                        if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS) && TEST_FLAG(flags, AP4FLAGMASK_FLAG_INITIATED)) {
                            activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
                            int mem_addr = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MAR]);
                            int mem_data = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_RESULT]);
                            int stage_id = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MBR2]);
                            ctxt->allocation.sync_data[stage_id].data[mem_addr] = mem_data;
                            ctxt->allocation.sync_data[stage_id].valid[mem_addr] = 1;
                            // rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[SNAPACK] stage %d index %d flags %x\n", stage_id, mem_addr, flags);
                        }
                        break;
                    case ACTIVE_STATE_REMAPPING:
                        if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS) && TEST_FLAG(flags, AP4FLAGMASK_FLAG_INITIATED)) {
                            if(ap4data != NULL) {
                                int mem_addr = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MAR]);
                                // int mem_data = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MBR]);
                                int stage_id = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MBR2]);
                                ctxt->membuf.sync_data[stage_id].valid[mem_addr] = 1;	
                            } else {
                                rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[ERROR] unable to parse args!\n");
                            }
                        }
                        break;
                    case ACTIVE_STATE_TRANSMITTING:
                        if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REMAPPED) && ctxt->allocation.version == seq) {
                            ctxt->allocation.sync_version = seq;
                            for(int i = 0; i < NUM_STAGES; i++) {
                                for(int j = 0; j < MAX_DATA; j++) {
                                    ctxt->allocation.sync_data[i].valid[j] = 0;
                                }
                            }
                            rte_memcpy(ctxt->allocation.syncmap, ctxt->allocation.valid_stages, NUM_STAGES);
                            ctxt->allocation.invalid = 1;
                            ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
                            rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] remap initiated.\n", fid);
                        }
                        if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_MARKED)) {
                            rx_update_state(cache, ap4data);
                        }
                        // rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "pkt length %d\n", pkts[k]->pkt_len);
                        break;
                    default:
                        break;
                }

                if(ctxt->status != current_state) {
                    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] state change %d -> %d\n", fid, current_state, ctxt->status);
                }
            }
        }

        for(uint16_t buf = 0; buf < nb_rx; buf++)
            rte_pktmbuf_free(bufs[buf]);
	}

    for(int i = 0; i < num_instances; i++) {
		ctxts[i].shutdown(i + 1, ctxts[i].app_context);
	}

    return 0;
}

#endif