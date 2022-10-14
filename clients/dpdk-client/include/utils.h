#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <net/ethernet.h>
#include <rte_ethdev.h>

#include "types.h"
#include "../../../headers/activep4.h"

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
    printf("]\n");
}

#endif