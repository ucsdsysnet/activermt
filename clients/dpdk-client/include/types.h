#ifndef TYPES_H
#define TYPES_H

#include <inttypes.h>

#include "../../../headers/activep4.h"

#define TEST_FLAG(x, y)		((x & y) > 0)

#define RX_RING_SIZE 		1024
#define TX_RING_SIZE 		1024
#define PORT_PETH			0

#define NUM_MBUFS 			8191
#define MBUF_CACHE_SIZE 	250
#define BURST_SIZE			32
#define DELAY_SEC			1000000
#define CTRL_SEND_INTVL_US	100
#define CTRL_HEARTBEAT_ITVL	1000
#define MAX_APPS			16
#define MAX_INSTANCES		16

#define AP4_ETHER_TYPE_AP4	0x83B2

typedef struct {
	int					num_apps_instances;
	activep4_context_t*	ctxt;
	uint32_t			app_id[MAX_APPS];
	uint32_t			instance_id[MAX_APPS];
} active_apps_t;

typedef struct {
	uint16_t				port_id;
	active_apps_t*			apps_ctxt;
	struct rte_mempool*		mempool;
} active_control_t;

typedef struct {
	int			num_apps;
	int			num_instances[MAX_APPS];
	char		appname[MAX_APPS][50];
	char		appdir[MAX_APPS][50];
	int			fid[MAX_APPS];
} active_config_t;

#endif