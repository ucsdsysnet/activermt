/**
 * @file active_lb.h
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

#ifndef ACTIVE_LB_H
#define ACTIVE_LB_H

#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <stdio.h>
#include <signal.h>
#include <stddef.h>
#include <inttypes.h>
#include <getopt.h>
#include <regex.h>
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
#include <rte_hash.h>

#include "../../../include/c/common/activep4.h"
#include "../../../include/c/dpdk/types.h"
#include "../../../include/c/dpdk/utils.h"
#include "../../../include/c/dpdk/memory.h"
#include "../../../include/c/dpdk/active.h"
#include "../../../include/c/dpdk/common.h"

#define DEBUG_LB

#define MAXCONN     1024

typedef struct {
    uint32_t    src_addr;
    uint32_t    dst_addr;
    uint8_t     proto;
    uint16_t    src_port;
    uint16_t    dst_port;
} __attribute__((packed)) inet_5tuple_t;

typedef struct {
    struct rte_hash*    ht;
} lb_context_t;

void shutdown_lb(int id, void* context) {}

void active_tx_mux_lb(void* buf, void* context, int* pid) {
    
    // lb_context_t* lb_ctxt = (lb_context_t*)context;
    char* bufptr = (char*)buf;

    struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
    if(ntohs(hdr_eth->ether_type) != RTE_ETHER_TYPE_IPV4) return;

    struct rte_ipv4_hdr* hdr_ipv4 = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr));
    if(hdr_ipv4->next_proto_id != IPPROTO_TCP) return;

    struct rte_tcp_hdr* hdr_tcp = (struct rte_tcp_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(struct rte_ipv4_hdr));
    *pid = (hdr_tcp->tcp_flags & RTE_TCP_SYN_FLAG) ? 0 : 1;

    // printf("[LB] selected program: %d\n", *pid);
}

void active_tx_handler_lb(void* inet_bufptr, activep4_data_t* ap4data, memory_t* alloc, void* context) {

    lb_context_t* lb_ctxt = (lb_context_t*)context;
    char* bufptr = (char*)inet_bufptr;

    struct rte_ipv4_hdr* hdr_ipv4 = (struct rte_ipv4_hdr*)bufptr;
    if(hdr_ipv4->next_proto_id != IPPROTO_TCP) return;

    struct rte_tcp_hdr* hdr_tcp = (struct rte_tcp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));

    memset(ap4data, 0, sizeof(activep4_data_t));
    
    if(hdr_tcp->tcp_flags & RTE_TCP_SYN_FLAG) {
        // ap4data->data[0] = 1;
        ap4data->data[1] = hdr_ipv4->dst_addr;
        // ap4data->data[2] = htonl(184);
        #ifdef DEBUG_LB
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[LB] TCP SYN source port %d\n", ntohs(hdr_tcp->src_port));
        #endif
    } else {
        const inet_5tuple_t flow = {
            .src_addr = hdr_ipv4->dst_addr,
            .dst_addr = hdr_ipv4->src_addr,
            .proto = hdr_ipv4->next_proto_id,
            .src_port = hdr_tcp->dst_port,
            .dst_port = hdr_tcp->src_port
        };
        uint32_t cookie = 0;
        if(rte_hash_lookup_data(lb_ctxt->ht, &flow, (void**)&cookie) >= 0) {
            // cookie retrieved.
            ap4data->data[0] = cookie;
            // printf("Cookie: %x\n", cookie);
        } else {
            // should have been installed upon connection setup.
            #ifdef DEBUG_LB
            rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[LB] error: cookie does not exist!\n");
            #endif
        }
    }
}

void active_rx_handler_lb(void* active_context, activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {
    lb_context_t* lb_ctxt = (lb_context_t*)context;
    inet_pkt_t* inet_pkt = (inet_pkt_t*)pkt;
    if(inet_pkt->hdr_tcp == NULL || ap4args->data[0] == 0) return;
    if(!(inet_pkt->hdr_tcp->tcp_flags & RTE_TCP_SYN_FLAG)) {
        #ifdef DEBUG_LB
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[LB] error: unexpected packet!\n");
        #endif
        return;
    }
    unsigned long cookie = ap4args->data[0];
    const inet_5tuple_t flow = {
        .src_addr = inet_pkt->hdr_ipv4->src_addr,
        .dst_addr = inet_pkt->hdr_ipv4->dst_addr,
        .proto = inet_pkt->hdr_ipv4->next_proto_id,
        .src_port = inet_pkt->hdr_tcp->src_port,
        .dst_port = inet_pkt->hdr_tcp->dst_port
    };
    rte_hash_add_key_data(lb_ctxt->ht, &flow, (void*)cookie);
    #ifdef DEBUG_LB
    rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[LB] Received cookie: %lx\n", cookie);
    #endif
}

int memory_consume_lb(memory_t* mem, void* context) { return 0; }

int memory_invalidate_lb(memory_t* mem, void* context) { return 0; }

int memory_reset_lb(memory_t* mem, void* context) { 
    lb_context_t* lb_ctxt = (lb_context_t*)context;
    struct rte_hash_parameters params = {
        .entries = MAXCONN,
        .key_len = sizeof(inet_5tuple_t),
        .hash_func = rte_hash_crc
    };
    lb_ctxt->ht = rte_hash_create(&params);
    return 0; 
}

void timer_lb(void* arg) {}

void static_allocation_lb(memory_t* mem) {
    int num_valid_stages = 4;
    int valid_stages[] = {3, 5, 14, 16};
    for(int i = 0; i < num_valid_stages; i++) {
        mem->valid_stages[valid_stages[i]] = 1;
        mem->sync_data[valid_stages[i]].mem_start = 0;
        mem->sync_data[valid_stages[i]].mem_end = MAX_DATA - 1;
    }
}

#endif