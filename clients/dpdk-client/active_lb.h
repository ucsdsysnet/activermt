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
#include <rte_pdump.h>

#include "../../headers/activep4.h"
#include "./include/types.h"
#include "./include/utils.h"
#include "./include/memory.h"
#include "./include/active.h"
#include "./include/common.h"

#define MAXCONN     1024

typedef struct {
    uint32_t    cookies[MAXCONN];
} lb_context_t;

void shutdown_lb(int id, void* context) {}

void active_tx_handler_lb(void* inet_hdrs, activep4_data_t* ap4data, memory_t* alloc, void* context) {
    lb_context_t* lb_ctxt = (lb_context_t*)context;
    inet_pkt_t* hdrs = (inet_pkt_t*)inet_hdrs;
    char* payload = hdrs->payload;
    int payload_length = hdrs->payload_length;
    memset(ap4data, 0, sizeof(activep4_data_t));
}

void active_rx_handler_lb(void* active_context, activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {}

int memory_consume_lb(memory_t* mem, void* context) { return 0; }

int memory_invalidate_lb(memory_t* mem, void* context) { return 0; }

int memory_reset_lb(memory_t* mem, void* context) { return 0; }

void timer_lb(void* arg) {}

#endif