#ifndef DECAP_H
#define DECAP_H

#include "types.h"
#include "utils.h"

static uint16_t
active_decap_filter(
	uint16_t port_id __rte_unused, 
	uint16_t queue __rte_unused, 
	struct rte_mbuf** pkts, 
	uint16_t nb_pkts, 
	void *ctxt
) {
	active_apps_t* apps_ctxt = (active_apps_t*)ctxt;

	// static uint64_t decap_ts_start = 0, decap_ts_end = 0, decap_ts_elapsed = 0;

	for(int k = 0; k < nb_pkts; k++) {
		char* bufptr = rte_pktmbuf_mtod(pkts[k], char*);
		inet_pkt_t inet_pkt = {0};
		struct rte_ether_hdr* hdr_eth = (struct rte_ether_hdr*)bufptr;
		int offset = 0;
		// decap_ts_start = rte_rdtsc_precise();
		if(ntohs(hdr_eth->ether_type) == RTE_ETHER_TYPE_IPV4) {
			// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] Non active packet.\n");
		} else if(ntohs(hdr_eth->ether_type) == AP4_ETHER_TYPE_AP4) {
			hdr_eth->ether_type = htons(RTE_ETHER_TYPE_IPV4);
			activep4_ih* ap4ih = (activep4_ih*)(bufptr + sizeof(struct rte_ether_hdr));
			activep4_data_t* ap4data = NULL;
			if(htonl(ap4ih->SIG) != ACTIVEP4SIG) continue;
			uint16_t flags = ntohs(ap4ih->flags);
			uint16_t fid = ntohs(ap4ih->fid);
			uint16_t seq = ntohs(ap4ih->seq);
			// Strip packet of active headers.
			offset += sizeof(activep4_ih);
			if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS)) {
				ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
				offset += sizeof(activep4_data_t);
			}
			if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
				offset += sizeof(activep4_malloc_res_t);
			}
			if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_EOE) || *(uint8_t*)(bufptr + sizeof(struct rte_ether_hdr) + offset) != 0x45) {
				offset += get_active_eof(bufptr + sizeof(struct rte_ether_hdr) + offset, pkts[k]->pkt_len);
			}
			// Get active app context.
			activep4_context_t* ctxt = NULL;
			for(int i = 0; i < apps_ctxt->num_apps; i++) {
				if(fid == apps_ctxt->ctxt[i].fid) ctxt = &apps_ctxt->ctxt[i];
			}
			if(ctxt == NULL) {
				rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] Unable to get app context from active packet!\n", fid);
				continue;
			}
			// Update control state.
			switch(ctxt->status) {
				case ACTIVE_STATE_INITIALIZING:
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REQALLOC)) {
						ctxt->status = ACTIVE_STATE_ALLOCATING;
					}
					break;
				case ACTIVE_STATE_REALLOCATING:
					// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] FID %d STATE %d Flags %x\n", ctxt->fid, ctxt->status, flags);
				case ACTIVE_STATE_ALLOCATING:
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
						if(ctxt->allocation.version != seq) {
							ctxt->telemetry.allocation_request_stop_ts = rte_rdtsc_precise();
							activep4_malloc_res_t* ap4malloc = (activep4_malloc_res_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
							ctxt->allocation.invalid = 0;
							ctxt->allocation.version = seq;
							ctxt->allocation.hash_function = NULL;
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] ALLOCATION (ver %d) ", fid, ctxt->allocation.version);
							for(int i = 0; i < NUM_STAGES; i++) {
								ctxt->allocation.sync_data[i].mem_start = ntohl(ap4malloc->mem_range[i].start);
								ctxt->allocation.sync_data[i].mem_end = ntohl(ap4malloc->mem_range[i].end);
								if((ctxt->allocation.sync_data[i].mem_end - ctxt->allocation.sync_data[i].mem_start) > 0) {
									ctxt->allocation.valid_stages[i] = 1;
									rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "{S%d: %d - %d} ", i, ctxt->allocation.sync_data[i].mem_start, ctxt->allocation.sync_data[i].mem_end);
								}
							}
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "\n");
							// TODO
							// ctxt->status = (ctxt->status == ACTIVE_STATE_ALLOCATING) ? ACTIVE_STATE_TRANSMITTING : ACTIVE_STATE_REMAPPING;
							mutate_active_program(ctxt->programs[ctxt->current_pid], &ctxt->allocation, 1, ctxt->instr_set);
							ctxt->telemetry.allocation_is_active = 0;
							ctxt->status = ACTIVE_STATE_REMAPPING;
							uint64_t allocation_elapsed_ns 
								= (double)(ctxt->telemetry.allocation_request_stop_ts - ctxt->telemetry.allocation_request_start_ts) * 1E9 / rte_get_tsc_hz();
							if(ctxt->telemetry.is_initializing == 1)
								rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] allocation time %ld ns\n", fid, allocation_elapsed_ns);
							else
								rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] reallocation time %ld ns\n", fid, allocation_elapsed_ns);
							ctxt->telemetry.is_initializing = 0;
							#ifdef DEBUG
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DEBUG] state %d\n", ctxt->status);
							#endif
						}
					}
					break;
				case ACTIVE_STATE_SNAPSHOTTING:
					if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS) && TEST_FLAG(flags, AP4FLAGMASK_FLAG_INITIATED)) {
						activep4_data_t* ap4data = (activep4_data_t*)(bufptr + sizeof(struct rte_ether_hdr) + sizeof(activep4_ih));
						int mem_addr = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MAR]);
						int mem_data = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_RESULT]);
						int stage_id = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MBR2]);
						ctxt->allocation.sync_data[stage_id].data[mem_addr] = mem_data;
						ctxt->allocation.sync_data[stage_id].valid[mem_addr] = 1;
						// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[SNAPACK] stage %d index %d flags %x\n", stage_id, mem_addr, flags);
					}
					break;
				case ACTIVE_STATE_REMAPPING:
					if(TEST_FLAG(flags, AP4FLAGMASK_OPT_ARGS) && TEST_FLAG(flags, AP4FLAGMASK_FLAG_INITIATED)) {
						if(ap4data != NULL) {
							int mem_addr = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MAR]);
							// int mem_data = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MBR]);
							int stage_id = ntohl(ap4data->data[ACTIVE_DEFAULT_ARG_MBR2]);
							ctxt->membuf.sync_data[stage_id].valid[mem_addr] = 1;	
						} else {
							rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[ERROR] unable to parse args!\n");
						}
					}
					break;
				case ACTIVE_STATE_TRANSMITTING:
					if(TEST_FLAG(flags, AP4FLAGMASK_FLAG_REMAPPED) && ctxt->allocation.version == seq) {
						ctxt->allocation.sync_version = seq;
						for(int i = 0; i < NUM_STAGES; i++) {
							for(int j = 0; j < MAX_DATA; j++) {
								ctxt->allocation.sync_data[i].valid[j] = 0;
							}
						}
						rte_memcpy(ctxt->allocation.syncmap, ctxt->allocation.valid_stages, NUM_STAGES);
						ctxt->allocation.invalid = 1;
						ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
						rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[FID %d] remap initiated.\n", fid);
					}
					if(!TEST_FLAG(flags, AP4FLAGMASK_FLAG_MARKED)) {
						inet_pkt.hdr_ipv4 = (struct rte_ipv4_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + offset);
						if(inet_pkt.hdr_ipv4->next_proto_id == IPPROTO_UDP) {
							inet_pkt.hdr_udp = (struct rte_udp_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + offset + sizeof(struct rte_ipv4_hdr));
							inet_pkt.payload = bufptr + sizeof(struct rte_ether_hdr) + offset + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_udp_hdr);
							inet_pkt.payload_length = ntohs(inet_pkt.hdr_udp->dgram_len) - sizeof(struct rte_udp_hdr);
						} else if(inet_pkt.hdr_ipv4->next_proto_id == IPPROTO_TCP) {
							inet_pkt.hdr_tcp = (struct rte_tcp_hdr*)(bufptr + sizeof(struct rte_ether_hdr) + offset + sizeof(struct rte_ipv4_hdr));
							inet_pkt.payload = bufptr + sizeof(struct rte_ether_hdr) + offset + sizeof(struct rte_ipv4_hdr) + sizeof(struct rte_tcp_hdr);
							inet_pkt.payload_length = ntohs(inet_pkt.hdr_ipv4->total_length) - inet_pkt.hdr_tcp->data_off * 4;
						}
						ctxt->rx_handler((void*)ctxt, ap4ih, ap4data, ctxt->app_context, (void*)&inet_pkt);
						for(int i = 0; i < pkts[k]->pkt_len - sizeof(struct rte_ether_hdr) - offset; i++) {
							bufptr[sizeof(struct rte_ether_hdr) + i] = bufptr[sizeof(struct rte_ether_hdr) + offset + i];
						}
						pkts[k]->pkt_len -= offset;
						pkts[k]->data_len -= offset;
						// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] FID %d Flags %x OFFSET %d PKTLEN %d IP dst %x\n", ctxt->fid, flags, offset, pkts[k]->pkt_len, inet_pkt.hdr_ipv4->dst_addr);
					}
					// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "pkt length %d\n", pkts[k]->pkt_len);
					break;
				default:
					break;
			}

			// assert(pkts[k]->pkt_len >= offset);
		} else {
			// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] Unknown packet: ");
			// print_pktinfo(bufptr, pkts[k]->pkt_len);
		}
		
		// decap_ts_end = rte_rdtsc_precise();
		// decap_ts_elapsed = (double)(decap_ts_end - decap_ts_start) * 1E9 / rte_get_tsc_hz();
		// rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[DECAP] elapsed time (ns): %lu\n", decap_ts_elapsed);
	}	

	return nb_pkts;
}

#endif