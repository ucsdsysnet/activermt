#ifndef ENCAP_H
#define ENCAP_H

#include "types.h"
#include "utils.h"

static  __rte_always_inline void insert_active_program_headers(activep4_context_t* ap4_ctxt, struct rte_mbuf* pkt) {

	assert(ap4_ctxt->tx_mux != NULL);
	assert(ap4_ctxt->tx_handler != NULL);
	
	char* bufptr = rte_pktmbuf_mtod(pkt, char*);

	ap4_ctxt->tx_mux(bufptr, ap4_ctxt->app_context, &ap4_ctxt->current_pid);

	active_mutant_t* program = &ap4_ctxt->programs[ap4_ctxt->current_pid]->mutant;

	struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
	hdr_eth->ether_type = htons(AP4_ETHER_TYPE_AP4);

	int ap4hlen = sizeof(activep4_ih) + sizeof(activep4_data_t) + (program->proglen * sizeof(activep4_instr));

	for(int i = pkt->pkt_len - 1; i >= sizeof(struct rte_ether_hdr); i--) {
		bufptr[i + ap4hlen] = bufptr[i];
	}

	activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
	ap4ih->SIG = htonl(ACTIVEP4SIG);
	ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS | AP4FLAGMASK_FLAG_PRELOAD);
	ap4ih->fid = htons(ap4_ctxt->fid);
	ap4ih->seq = htons(0);

	activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));

	for(int i = 0; i < program->proglen; i++) {
		activep4_instr* instr = (activep4_instr*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih) + sizeof(activep4_data_t) + (i * sizeof(activep4_instr)));
		instr->flags = program->code[i].flags;
		instr->opcode = program->code[i].opcode;
	}

	char* inet_bufptr = bufptr + sizeof(struct rte_ether_hdr) + ap4hlen;
	ap4_ctxt->tx_handler(inet_bufptr, ap4data, &ap4_ctxt->allocation, ap4_ctxt->app_context);

	pkt->pkt_len += ap4hlen;
	pkt->data_len += ap4hlen;
}

static  __rte_always_inline activep4_context_t* get_app_context_from_packet(char* bufptr, active_apps_t* apps_ctxt) {
	struct rte_ipv4_hdr* iph = (struct rte_ipv4_hdr*)bufptr;
	uint32_t app_id = 0;
	activep4_context_t* ctxt = NULL;
	if(iph->next_proto_id == IPPROTO_UDP) {
		struct rte_udp_hdr* udph = (struct rte_udp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));
		app_id = ntohs(udph->dst_port);
	} else if(iph->next_proto_id == IPPROTO_TCP) {
		struct rte_tcp_hdr* tcph = (struct rte_tcp_hdr*)(bufptr + sizeof(struct rte_ipv4_hdr));
		app_id = ntohs(tcph->dst_port);
	} else return NULL;
	for(int j = 0; j < apps_ctxt->num_apps; j++) {
		if(apps_ctxt->app_id[j] == app_id) {
			ctxt = &apps_ctxt->ctxt[j];
			assert(ctxt != NULL);
			ctxt->id = j;
			ctxt->is_active = true;
		}
	}
	return ctxt;
}

static uint16_t
active_encap_filter(
	uint16_t port_id __rte_unused, 
	uint16_t queue __rte_unused, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	uint16_t max_pkts,
	void *ctxt
) {
	active_apps_t* apps_ctxt = (active_apps_t*)ctxt;

	for(int i = 0; i < nb_pkts; i++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[i], char*);
		struct rte_ether_hdr* eth = (struct rte_ether_hdr*)bufptr;
		if(eth->ether_type != htons(RTE_ETHER_TYPE_IPV4)) continue;
		activep4_context_t* ctxt = get_app_context_from_packet(bufptr + sizeof(struct rte_ether_hdr), apps_ctxt);
		if(ctxt == NULL || !ctxt->active_tx_enabled) continue;
		#ifdef STATS
		update_active_tx_stats(ctxt->status, &apps_ctxt->stats[ctxt->id]);
		#endif
		switch(ctxt->status) {
			case ACTIVE_STATE_TRANSMITTING:
				insert_active_program_headers(ctxt, pkts[i]);
				break;
			default:
				break;
		}
	}

	#ifdef DEBUG
	if(nb_pkts > 0)
		rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "Received %d packets.\n", nb_pkts);
	#endif

	return nb_pkts;
}

#endif