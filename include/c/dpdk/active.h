#ifndef ACTIVE_H
#define ACTIVE_H

// #define DEBUG_ACTIVEPKT

#include <rte_mbuf.h>
#include <rte_malloc.h>
#include <rte_ethdev.h>

#include "types.h"
#include "../common/activep4.h"

static  __rte_always_inline void construct_reqalloc_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	activep4_def_t* program = ctxt->programs[ctxt->current_pid];
	assert(program != NULL);
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_REQALLOC);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	activep4_malloc_req_t* mreq = (activep4_malloc_req_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	memset(mreq, 0, sizeof(activep4_malloc_req_t));
	mreq->proglen = htons((uint16_t)program->proglen);
	mreq->iglim = (uint8_t)program->iglim;
	#ifdef DEBUG_ACTIVEPKT
	printf("[DEBUG_ACTIVEPKT] FID %d reqalloc %d accesses: demands ", ctxt->fid, ctxt->programs[ctxt->current_pid]->num_accesses);
	#endif
	for(int i = 0; i < program->num_accesses; i++) {
		mreq->mem[i] = program->access_idx[i];
		mreq->dem[i] = program->demand[i];
	}
	#ifdef DEBUG_ACTIVEPKT
	for(int i = 0; i < 8; i++) printf("%d ", mreq->dem[i]);
	printf("\n");
	#endif
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static  __rte_always_inline void construct_dealloc_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	activep4_def_t* program = ctxt->programs[ctxt->current_pid];
	assert(program != NULL);
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_REQALLOC);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	activep4_malloc_req_t* mreq = (activep4_malloc_req_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	memset(mreq, 0, sizeof(activep4_malloc_req_t));
	mreq->proglen = htons((uint16_t)program->proglen);
	mreq->iglim = (uint8_t)program->iglim;
	#ifdef DEBUG_ACTIVEPKT
	printf("[DEBUG_ACTIVEPKT] FID %d reqalloc %d accesses: demands ", ctxt->fid, ctxt->programs[ctxt->current_pid]->num_accesses);
	#endif
	for(int i = 0; i < program->num_accesses; i++) {
		mreq->mem[i] = program->access_idx[i];
		mreq->dem[i] = 0;
	}
	#ifdef DEBUG_ACTIVEPKT
	for(int i = 0; i < 8; i++) printf("%d ", mreq->dem[i]);
	printf("\n");
	#endif
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_malloc_req_t) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static  __rte_always_inline void construct_getalloc_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr)); 
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_FLAG_GETALLOC);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static  __rte_always_inline void construct_reallocate_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_ACK | AP4FLAGMASK_FLAG_GETALLOC);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t* program = NULL;
	program = (activep4_def_t*)rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
	construct_nop_program(program, ctxt->instr_set, 0);
	if(program == NULL) {
		rte_exit(EXIT_FAILURE, "Could not construct completion program!\n");
		return;
	}
	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program->code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static  __rte_always_inline void construct_snapshot_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt, int stage_id, int mem_addr, activep4_def_t* memsync_cache, bool complete) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = (complete) ? htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_ACK) : htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_INITIATED | AP4FLAGMASK_FLAG_PRELOAD);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t* program = NULL;
	if(complete) {
		program = (activep4_def_t*)rte_zmalloc(NULL, sizeof(activep4_def_t), 0);
		construct_nop_program(program, ctxt->instr_set, 0);
	} else {
		ap4data->data[ACTIVE_DEFAULT_ARG_MAR] = htonl((uint32_t)mem_addr);
		ap4data->data[ACTIVE_DEFAULT_ARG_MBR2] = htonl((uint32_t)stage_id);
		program = construct_memsync_program(ctxt->fid, stage_id, ctxt->instr_set, memsync_cache);
	}
	if(program == NULL) {
		rte_exit(EXIT_FAILURE, "Could not construct memsync/completion program!\n");
		return;
	}
	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program->code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static  __rte_always_inline void construct_heartbeat_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_MARKED);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	activep4_def_t program = {0};
	construct_nop_program(&program, ctxt->instr_set, 0);
	for(int i = 0; i < program.proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program.code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program.proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program.proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

static  __rte_always_inline void construct_memremap_packet(struct rte_mbuf* mbuf, int port_id, activep4_context_t* ctxt, int stage_id, int mem_addr, uint32_t data, activep4_def_t* memset_cache) {
	char* bufptr = rte_pktmbuf_mtod(mbuf, char*);
	struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
	eth->ether_type = htons(AP4_ETHER_TYPE_AP4);
	struct rte_ether_addr eth_addr;
	if(rte_eth_macaddr_get(port_id, &eth_addr) < 0) {
		printf("Unable to get device MAC address!\n");
		return;
	}
	rte_memcpy(&eth->dst_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	rte_memcpy(&eth->src_addr, (void*)&eth_addr, sizeof(struct rte_ether_addr));
	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_INITIATED | AP4FLAGMASK_FLAG_PRELOAD);
	ap4ih->fid = htons(ctxt->fid);
	ap4ih->seq = 0;
	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
	for(int i = 0; i < AP4_DATA_LEN; i++) ap4data->data[i] = 0;
	ap4data->data[ACTIVE_DEFAULT_ARG_MAR] = htonl((uint32_t)mem_addr);
	ap4data->data[ACTIVE_DEFAULT_ARG_MBR] = htonl(data);
	ap4data->data[ACTIVE_DEFAULT_ARG_MBR2] = htonl((uint32_t)stage_id);
	activep4_def_t* program = construct_memset_program(ctxt->fid, stage_id, ctxt->instr_set, memset_cache);
	if(program == NULL) {
		rte_exit(EXIT_FAILURE, "Could not construct memset program!\n");
		return;
	}
	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = 0;
		instr->opcode = program->code[i].opcode;
	}
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)));
	iph->version = 4;
	iph->ihl = 5;
	iph->type_of_service = 0;
	iph->total_length = htons(sizeof(struct rte_ipv4_hdr));
	iph->packet_id = 0;
	iph->fragment_offset = 0;
	iph->time_to_live = 64;
	iph->next_proto_id = 0;
	iph->hdr_checksum = 0;
	iph->src_addr = ctxt->ipv4_srcaddr;
	iph->dst_addr = ctxt->ipv4_srcaddr;
	iph->hdr_checksum = rte_ipv4_cksum(iph);
	mbuf->pkt_len = sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr)) + sizeof(struct rte_ipv4_hdr);
	mbuf->data_len = mbuf->pkt_len;
}

#endif