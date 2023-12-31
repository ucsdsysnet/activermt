/**
 * @file types.h
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

#ifndef TYPES_H
#define TYPES_H

#include <inttypes.h>
#include <rte_hash.h>

#include "../common/activep4.h"

// #define CTRL_MULTICORE
// #define CTRL_PARALLEL
#define STATS

#define TEST_FLAG(x, y)		((x & y) > 0)

#define NUM_RX_QUEUES		1
#define NUM_TX_QUEUES		2
#define RX_RING_SIZE 		1024
#define TX_RING_SIZE 		1024
#define PORT_PETH			0

#define NUM_MBUFS 			8191
#define MBUF_CACHE_SIZE 	250
#define BURST_SIZE			32
#define DELAY_SEC			1000000
#define CTRL_SEND_INTVL_US	100
#define CTRL_HEARTBEAT_ITVL	1000
#define MAX_APPS			1024
#define MAX_PROGRAMS_APP	8
#define MAX_STATS_SAMPLES	1000
#define MAX_TXSTAT_SAMPLES	1000000
#define STATS_ITVL_MS		1

#define AP4_ETHER_TYPE_AP4	0x83B2

#define CTRL_PKT_REQALLOC	1
#define CTRL_PKT_GETALLOC	2
#define CTRL_PKT_SNAPSHOT	3
#define CTRL_PKT_SNAPCMPLT	4
#define CTRL_PKT_HEARTBEAT	5

typedef struct {
	uint32_t	tx_active[MAX_TXSTAT_SAMPLES];
	uint32_t	tx_total[MAX_TXSTAT_SAMPLES];
	uint64_t	ts[MAX_TXSTAT_SAMPLES];
	uint64_t	ts_ref;
	uint64_t	ts_last;
	int			num_samples;
} active_app_stats_t;

typedef struct {
	int			snapshotting_in_progress;
	int			remapping_in_progress;
	int			invalidating_in_progress;
	int			current_stage;
	int			current_index;
	uint32_t	counter;
} active_control_state_t;

typedef struct {
	int						num_apps;
	activep4_context_t*		ctxt;
	active_control_state_t	ctrl_status[MAX_APPS];	
	active_app_stats_t*		stats;
	uint32_t				app_id[MAX_APPS];
} active_apps_t;

typedef struct {
	uint16_t				port_id;
	active_apps_t*			apps_ctxt;
	struct rte_mempool*		mempool;
} active_control_t;

typedef struct {
	active_control_t*		ctrl;
	int						app_id;
} active_control_app_t;

typedef struct {
	char		program_path[1024];
	char		program_name[50];
} active_program_path_t;

typedef struct {
	int						app_id;
	char					appname[128];
	active_program_path_t*	functions[MAX_PROGRAMS_APP];
	int						num_functions;
} active_application_t;

typedef struct {
	int						num_apps;
	int						num_programs;
	active_application_t	active_apps[MAX_APPS];
	active_program_path_t	active_programs[MAX_APPS];
} active_config_t;

typedef struct {
	uint64_t	rx_pkts[MAX_STATS_SAMPLES];
	uint64_t	tx_pkts[MAX_STATS_SAMPLES];
	uint64_t	ts[MAX_STATS_SAMPLES];
	int			num_samples;
} active_dpdk_stats_t;

typedef struct {
	struct rte_ipv4_hdr*	hdr_ipv4;
	struct rte_udp_hdr*		hdr_udp;
	struct rte_tcp_hdr*		hdr_tcp;
	char*					payload;
	int						payload_length;
} inet_pkt_t;

static int is_running;

#ifdef CTRL_MULTICORE
static struct rte_eth_dev_tx_buffer* tx_buffers[MAX_TX_BUFS];
#else
static struct rte_eth_dev_tx_buffer* buffer;
static uint64_t drop_counter;
#endif

static struct rte_mempool* mbuf_pool;

#endif