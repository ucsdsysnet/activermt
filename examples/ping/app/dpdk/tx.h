#ifndef TX_H
#define TX_H

#include <rte_mempool.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>

#include "../../../../include/c/dpdk/types.h"
#include "ping.h"

#define TX_BURST_SIZE			1
#define REUSE_BUFFERS

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
        activep4_data_t* ap4data = NULL;

        if(activate_packets) {
            activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
            ap4ih->SIG = htonl(ACTIVEP4SIG);
            ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_PRELOAD);
            ap4ih->fid = htons(ctxt->fid);
            ap4ih->seq = 0;
            ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
            for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
            uint64_t now = rte_rdtsc_precise();
            ap4data->data[0] = now & 0xFFFFFFFF;
            ap4data->data[1] = (now >> 32) & 0xFFFFFFFF;
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
        iph->src_addr = APP_IPV4_ADDR;
        iph->dst_addr = iph->src_addr;
        iph->hdr_checksum = rte_ipv4_cksum(iph);

        struct rte_udp_hdr* udph = (struct rte_udp_hdr*)(bufptr + offset + sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr));
        udph->src_port = htons(9876);
        udph->dst_port = htons(9877);
        udph->dgram_len = htons(sizeof(struct rte_udp_hdr));
        udph->dgram_cksum = 0;

        mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr) + offset;
        mbuf->data_len = mbuf->pkt_len;
    }
}

static __rte_always_inline void
update_packet(struct rte_mbuf* mbuf) {
    char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
    activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
    if(ap4ih->SIG == htonl(ACTIVEP4SIG)) {
        activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
        uint64_t now = rte_rdtsc_precise();
        ap4data->data[0] = now & 0xFFFFFFFF;
        ap4data->data[1] = (now >> 32) & 0xFFFFFFFF;
    }
}

static int
lcore_tx(void* arg) {

    tx_config_t* cfg = (tx_config_t*)arg;

    int port_id = cfg->port_id;

    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "TX thread running for port %d on lcore %d\n", port_id, rte_lcore_id());

    struct rte_mbuf* mbufs[TX_BURST_SIZE]; 

    const int qid = 0;

    #ifdef REUSE_BUFFERS
    if(rte_mempool_get_bulk(mbuf_pool, (void**)mbufs, TX_BURST_SIZE) != 0) return -1;
    construct_packets_bulk(cfg, 0, mbufs, TX_BURST_SIZE);
    #endif

    while(is_running) {

        rte_delay_us(10); // avoid queue buildups.

        for(int i = 0; i < cfg->num_active; i++) {

            #ifdef REUSE_BUFFERS
            for(int j = 0; j < TX_BURST_SIZE; j++) {
                update_packet(mbufs[j]);
            }
            #else
            if(rte_mempool_get_bulk(mbuf_pool, (void**)mbufs, TX_BURST_SIZE) != 0) continue;
            construct_packets_bulk(cfg, i, mbufs, TX_BURST_SIZE);
            #endif
            
            uint16_t nb_tx = rte_eth_tx_burst(port_id, qid, mbufs, TX_BURST_SIZE);
            if(unlikely(nb_tx < TX_BURST_SIZE)) {
                #ifndef REUSE_BUFFERS
                uint16_t buf;
                for(buf = nb_tx; buf < TX_BURST_SIZE; buf++)
                    rte_pktmbuf_free(mbufs[buf]);
                #endif
            }
        }
    }

    return 0;
}

#endif