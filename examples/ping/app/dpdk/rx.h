/**
 * @file rx.h
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

#ifndef RX_H
#define RX_H

#include <rte_ethdev.h>

#include "../../../../include/c/dpdk/types.h"
#include "ping.h"

#define RX_BURST_SIZE			32
#define SAMPLE_RATE             100

typedef struct {
    activep4_context_t*     ctxt;
    int                     num_instances;
    int                     port_id;
    uint64_t                current_count;
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
    } else {
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d on local NUMA node.\n", port_id);
    }

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Port %d Queues RX %d Tx %d\n", port_id, dev_info.nb_rx_queues, dev_info.nb_tx_queues);

    printf("Ctrl+C to exit ... \n");

    const int qid = 0;

    while(is_running) {
		struct rte_mbuf* bufs[RX_BURST_SIZE];
        const uint16_t nb_rx = rte_eth_rx_burst(port_id, qid, bufs, RX_BURST_SIZE);
        uint64_t now = rte_rdtsc_precise();
        
        if (unlikely(nb_rx == 0))
            continue;

        for(int p = 0; p < nb_rx; p++) {

            char* bufptr = rte_pktmbuf_mtod(bufs[p], char*);

            struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;

            int offset = 0;

            if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {

                cfg->current_count++;
                
                activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
                if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
                
                uint16_t flags = ntohs(ap4ih->flags);
			    uint16_t fid = ntohs(ap4ih->fid);

                activep4_data_t* ap4data = NULL;
                offset += sizeof(activep4_ih);
                if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
                    ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
                }

                activep4_context_t* ctxt = NULL;
                ping_context_t* ping = NULL;
                for(int i = 0; i < num_instances; i++) {
                    if(fid == ctxts[i].fid) {
                        ctxt = &ctxts[i];
                        ping = (ping_context_t*)ctxt->app_context;
                    }
                }

                if(ctxt == NULL || ping == NULL) continue;

                if(cfg->current_count > SAMPLE_RATE) {
                    if(ap4data != NULL && ping->num_samples < MAX_SAMPLES) {
                        uint64_t then = ap4data->data[0] | ((uint64_t)ap4data->data[1] << 32);
                        uint64_t diff = ((now - then) * 1.0f / rte_get_tsc_hz()) * 1000000000;
                        ping->ping_times_ns[ping->num_samples++] = diff;
                    }
                    cfg->current_count = 0;
                }

                switch(ctxt->status) {
                    case ACTIVE_STATE_INITIALIZING:
                    case ACTIVE_STATE_DEALLOCATING:
                    case ACTIVE_STATE_DEALLOCWAIT:
                    case ACTIVE_STATE_REALLOCATING:
                    case ACTIVE_STATE_ALLOCATING:
                    case ACTIVE_STATE_SNAPSHOTTING:
                    case ACTIVE_STATE_UPDATING:
                    case ACTIVE_STATE_REMAPPING:
                    case ACTIVE_STATE_TRANSMITTING:
                    default:
                        break;
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