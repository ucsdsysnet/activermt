#ifndef ACTIVE_HH_H
#define ACTIVE_HH_H

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

typedef struct {
    uint64_t			last_computed_freq;
} hh_context_t;

void shutdown_hh(int id, void* context) {}

void active_tx_handler_hh(char* payload, int payload_length, activep4_data_t* ap4data, memory_t* alloc, void* context) {
    hh_context_t* hh_ctxt = (hh_context_t*)context;
    memset(ap4data, 0, sizeof(activep4_data_t));
}

void active_rx_handler_hh(void* active_context, activep4_ih* ap4ih, activep4_data_t* ap4args, void* context, void* pkt) {}

int memory_consume_hh(memory_t* mem, void* context) { return 0; }

int memory_invalidate_hh(memory_t* mem, void* context) { return 0; }

int memory_reset_hh(memory_t* mem, void* context) { return 0; }

void timer_hh(void* arg) {}

#endif