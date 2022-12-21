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

void read_activep4_config(char* config_filename, active_config_t* cfg) {
	FILE* fp = fopen(config_filename, "r");
    assert(fp != NULL);
	char buf[50];
    const char* tok;
	int i, n = 0;
	while( fgets(buf, 50, fp) > 0 ) {
		for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, ",\n"), i++) {
			switch(i) {
				case 0:
					cfg->fid[n] = atoi(tok);
					break;
				case 1:
					strcpy(cfg->appdir[n], tok);
					break;
				case 2:
					strcpy(cfg->appname[n], tok);
					break;
				case 3:
					cfg->num_instances[n] = atoi(tok);
					break;
				case 4:
					cfg->app_id[n] = atoi(tok);
					break;
				default:
					break;
			}
		}
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

static inline void print_hwaddr(unsigned char* hwaddr) {
    printf("%.2x:%.2x:%.2x:%.2x:%.2x:%.2x", hwaddr[0], hwaddr[1], hwaddr[2], hwaddr[3], hwaddr[4], hwaddr[5]);
}

static inline void print_ipv4_addr(uint32_t ipv4addr) {
    char buf[100];
    inet_ntop(AF_INET, &ipv4addr, buf, 16);
    printf("%s", buf);
}

static inline void print_pktinfo(char* buf, int pktlen) {
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

#endif