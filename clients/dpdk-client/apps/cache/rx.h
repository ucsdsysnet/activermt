#ifndef RX_H
#define RX_H

#include <rte_ethdev.h>

#include "../../include/types.h"

static int
lcore_rx(void* arg) {

    int port_id = *((int*)arg);

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

        #ifdef DEBUG
        /*rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[PORT %d][RX] %d pkts.\n", port, nb_rx);
        for(int i = 0; i < nb_rx; i++) {
            char* pkt = rte_pktmbuf_mtod(bufs[i], char*);
            print_pktinfo(pkt, bufs[i]->pkt_len);
        }*/
        #endif

        for(uint16_t buf = 0; buf < nb_rx; buf++)
            rte_pktmbuf_free(bufs[buf]);
	}

    return 0;
}

#endif