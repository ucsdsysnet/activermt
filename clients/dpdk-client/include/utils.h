#ifndef UTILS_H
#define UTILS_H

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <net/ethernet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <rte_ethdev.h>

#include "types.h"
#include "../../../headers/activep4.h"

#define DISPLAY_BUFFER_SIZE     65536
#define MAX_DISPLAY_FIELDS      16

pthread_mutex_t buflock;

void read_active_program_config(char* config_filename, active_config_t* cfg) {
	FILE* fp = fopen(config_filename, "r");
    assert(fp != NULL);
	char buf[1024];
    const char* tok;
	int i, n = 0;
	while( fgets(buf, 1024, fp) > 0 ) {
		for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, ",\n"), i++) {
			switch(i) {
				case 0:
					strcpy(cfg->active_programs[n].program_name, tok);
					break;
				case 1:
					strcpy(cfg->active_programs[n].program_path, tok);
					break;
				default:
					break;
			}
		}
		n++;
	}
	cfg->num_programs = n;
	fclose(fp);
}

void read_activep4_config(char* config_filename, active_config_t* cfg) {
	FILE* fp = fopen(config_filename, "r");
    assert(fp != NULL);
	char buf[1024];
    const char* tok;
	int i, n = 0;
	while( fgets(buf, 1024, fp) > 0 ) {
		int m = 0;
		for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, ",\n"), i++) {
			switch(i) {
				case 0:
					cfg->active_apps[n].app_id = atoi(tok);
					break;
				case 1:
					strcpy(cfg->active_apps[n].appname, tok);
					break;
				default:
					for(int j = 0; j < cfg->num_programs; j++) {
						if(strcmp(cfg->active_programs[j].program_name, tok) == 0) {
							cfg->active_apps[n].functions[m++] = &cfg->active_programs[j];
							break;
						}
					}
					break;
			}
		}
		cfg->active_apps[n].num_functions = m;
		n++;
	}
	cfg->num_apps = n;
	fclose(fp);
}

uint32_t get_iface_ipv4_addr(char* dev) {

	int sockfd = 0;
	if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(EXIT_FAILURE);
    }

	uint32_t ipv4_ifaceaddr = 0;
	size_t if_name_len = strlen(dev);
	struct ifreq ifr;
	if(if_name_len < sizeof(ifr.ifr_name)) {
        memcpy(ifr.ifr_name, dev, if_name_len);
        ifr.ifr_name[if_name_len] = 0;
    } else {
        fprintf(stderr, "Interface name is too long!\n");
        exit(1);
    }
	ifr.ifr_addr.sa_family = AF_INET;
    if(ioctl(sockfd, SIOCGIFADDR, &ifr) < 0) {
        perror("ioctl");
        exit(1);
    }
    memcpy(&ipv4_ifaceaddr, &((struct sockaddr_in*)&ifr.ifr_addr)->sin_addr.s_addr, sizeof(uint32_t));

	return ipv4_ifaceaddr;
}

static __rte_always_inline void print_hwaddr(unsigned char* hwaddr) {
    printf("%.2x:%.2x:%.2x:%.2x:%.2x:%.2x", hwaddr[0], hwaddr[1], hwaddr[2], hwaddr[3], hwaddr[4], hwaddr[5]);
}

static __rte_always_inline void print_ipv4_addr(uint32_t ipv4addr) {
    char buf[100];
    inet_ntop(AF_INET, &ipv4addr, buf, 16);
    printf("%s", buf);
}

static __rte_always_inline void print_pktinfo(char* buf, int pktlen) {
    struct ethhdr* eth = (struct ethhdr*) buf;
    int offset = 0;
    if(ntohs(eth->h_proto) == AP4_ETHER_TYPE_AP4) {
        offset += sizeof(activep4_ih);
        if(ntohs(((activep4_ih*)&eth[1])->flags) & AP4FLAGMASK_OPT_ARGS) offset += sizeof(activep4_data_t);
        offset += get_active_eof(buf + sizeof(struct ethhdr) + offset, pktlen - offset);
    }
    struct iphdr* iph = (struct iphdr*) (buf + sizeof(struct ethhdr) + offset);
    printf("[0x%x] [", ntohs(eth->h_proto));
    print_ipv4_addr(iph->saddr);
    printf(" -> ");
    print_ipv4_addr(iph->daddr);
    printf("] [");
    print_hwaddr(eth->h_source);
    printf(" -> ");
    print_hwaddr(eth->h_dest);
    printf("] [%x] ", iph->protocol);
    printf("\n");
}

static __rte_always_inline void get_rw_stages_str(activep4_context_t* ctxt, char* stages_str) {
	int offset = 0;
	for(int i = 0; i < NUM_STAGES; i++) {
		if(!ctxt->allocation.valid_stages[i] || !ctxt->allocation.syncmap[i]) continue;
		if((offset = sprintf(stages_str, "%d ", i)) >= 0) {
			stages_str += offset;
		}
	}
}

static __rte_always_inline void telemetry_allocation_start(activep4_context_t* ctxt) {
	if(ctxt->telemetry.allocation_is_active == 0) {
		ctxt->telemetry.allocation_request_start_ts = rte_rdtsc_precise();
		ctxt->telemetry.allocation_is_active = 1;
	}
}

static  __rte_always_inline void update_active_tx_stats(int status, active_app_stats_t* stats) {
	stats->tx_total[stats->num_samples]++;
	if(status == ACTIVE_STATE_TRANSMITTING) {
		stats->tx_active[stats->num_samples]++;
	}
	uint64_t now = rte_rdtsc_precise();
	uint64_t elapsed_ms = (double)(now - stats->ts_last) * 1E3 / rte_get_tsc_hz();
	if(elapsed_ms >= STATS_ITVL_MS && stats->num_samples < MAX_TXSTAT_SAMPLES) {
		stats->ts_last = now;
		stats->ts[stats->num_samples] = (double)(now - stats->ts_ref) * 1E3 / rte_get_tsc_hz();
		stats->num_samples++;
	}
}

static  __rte_always_inline void write_active_tx_stats(active_apps_t* apps) {
	rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[INFO] writing active TX stats ... \n");
	for(int i = 0; i < apps->num_apps; i++) {
		if(apps->stats[i].num_samples == 0) continue;
		char filename[50];
		sprintf(filename, "active_tx_stats_%d.csv", apps->ctxt[i].fid);
		FILE* fp = fopen(filename, "w");
		for(int j = 0; j < apps->stats[i].num_samples; j++) {
			fprintf(fp, "%lu,%u,%u\n", apps->stats[i].ts[j], apps->stats[i].tx_active[j], apps->stats[i].tx_total[j]);
		}
		fclose(fp);
	}
}

#endif