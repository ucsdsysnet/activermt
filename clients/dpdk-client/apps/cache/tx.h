#ifndef TX_H
#define TX_H

#include <rte_mempool.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>

#include "../../include/types.h"
#include "cache.h"

typedef struct {
    activep4_context_t* ctxt;
    int                 num_instances;
    int                 num_active;
    int                 port_id;
} tx_config_t;

static __rte_always_inline void
construct_packets_bulk(tx_config_t* cfg, int appidx, struct rte_mbuf** mbufs, int n) {

    int port_id = cfg->port_id;

    activep4_context_t* ctxt = &cfg->ctxt[appidx];
    cache_context_t* cache = (cache_context_t*)ctxt->app_context;
    
    for(int i = 0; i < n; i++) {
        
        struct rte_mbuf* mbuf = mbufs[i];
        
        char* bufptr = rte_pktmbuf_mtod(mbuf, char*);

        int activate_packets = ctxt->is_active && (ctxt->status == ACTIVE_STATE_TRANSMITTING || ctxt->status == ACTIVE_STATE_UPDATING);
        
        struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
        eth->ether_type = (activate_packets) ? htons(AP4_ETHER_TYPE_AP4) : htons(RTE_ETHER_TYPE_IPV4);
        
        struct rte_ether_addr eth_addr;
        if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
            printf("Unable to get device MAC address!\n");
            return;
        }
        rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
        rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));

        int offset = 0;

        if(activate_packets) {
            activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
            ap4ih->SIG = htonl(ACTIVEP4SIG);
            ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_PRELOAD);
            ap4ih->fid = htons(ctxt->fid);
            ap4ih->seq = 0;
            activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
            for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
            tx_update_args(cache, ap4data);
            active_mutant_t* program = &ctxt->programs[ctxt->current_pid]->mutant;
            for(int i = 0; i < program->proglen; i++) {
                activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
                instr->flags = 0;
                instr->opcode = program->code[i].opcode;
            }
            offset += sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr));
        }

        struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + offset + sizeof(struct rte_ether_hdr));
        iph->version = 4;
        iph->ihl = 5;
        iph->type_of_service = 0;
        iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
        iph->packet_id = 0;
        iph->fragment_offset = 0;
        iph->time_to_live = 64;
        iph->next_proto_id = IPPROTO_UDP;
        iph->hdr_checksum = 0;
        iph->src_addr = ctxt->ipv4_srcaddr;
        iph->dst_addr = cache->ipv4_dstaddr;
        iph->hdr_checksum = rte_ipv4_cksum(iph);

        struct rte_udp_hdr* udph = (struct rte_udp_hdr*)(bufptr + offset + sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr));
        udph->src_port = htons(cache->app_port);
        udph->dst_port = htons(cache->app_port);
        udph->dgram_len = htons(sizeof(struct rte_udp_hdr));
        udph->dgram_cksum = 0;

        // char* payload = bufptr + offset + sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr);

        mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr) + offset;
        mbuf->data_len = mbuf->pkt_len;
    }
}

static int
lcore_tx(void* arg) {

    tx_config_t* cfg = (tx_config_t*)arg;

    int port_id = cfg->port_id;

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "TX thread running for port %d on lcore %d\n", port_id, rte_lcore_id());

    struct rte_mbuf* mbufs[BURST_SIZE];

    const int qid = 0;

    while(is_running) {

        // rte_delay_ms(1); continue;

        for(int i = 0; i < cfg->num_active; i++) {

            if(rte_mempool_get_bulk(mbuf_pool, (void**)mbufs, BURST_SIZE) != 0) continue;

            construct_packets_bulk(cfg, i, mbufs, BURST_SIZE);

            uint16_t nb_tx = rte_eth_tx_burst(port_id, qid, mbufs, BURST_SIZE);
            if(unlikely(nb_tx < BURST_SIZE)) {
                uint16_t buf;
                for(buf = nb_tx; buf < BURST_SIZE; buf++)
                    rte_pktmbuf_free(mbufs[buf]);
            }
        }
    }

    return 0;
}

#endif