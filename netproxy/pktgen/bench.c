#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>

#define BUFSIZE 4096

static int get_iface_index(char* dev, int fd) {
    struct ifreq ifr;
    size_t if_name_len = strlen(dev);
    if(if_name_len < sizeof(ifr.ifr_name)) {
        memcpy(ifr.ifr_name, dev, if_name_len);
        ifr.ifr_name[if_name_len] = 0;
    } else {
        fprintf(stderr, "interface name is too long\n");
        exit(1);
    }
    if (ioctl(fd, SIOCGIFINDEX, &ifr) < 0) {
        perror("ioctl");
        exit(1);
    }
    return ifr.ifr_ifindex;
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage: %s <iface> <ipv4_dstaddr>\n", argv[0]);
        exit(1);
    }

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    char eth_dst[] = "00:00:00:00:00:00";
    char ipv4_srcaddr[] = "10.0.0.1";

    char* iface = argv[1];
    char* ipv4_dstaddr = argv[2];

    int sockfd;

    struct sockaddr_in sockin;
    struct sockaddr_ll eth_dst_addr = {0};

    struct ethhdr*          eth;
    struct iphdr*           iph;

    char* pptr;

    char sendbuf[BUFSIZE];

    sockin.sin_family = AF_INET;
    sockin.sin_port = htons(1234);
    sockin.sin_addr.s_addr = inet_addr(ipv4_dstaddr);

    if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }

    int iface_index = get_iface_index(iface, sockfd);

    eth_dst_addr.sll_family = AF_PACKET;
    eth_dst_addr.sll_ifindex = iface_index;
    eth_dst_addr.sll_protocol = htons(ETH_P_IP);
    eth_dst_addr.sll_halen = ETH_ALEN;

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    memset(sendbuf, 0, BUFSIZE);
    pptr = sendbuf;

    eth = (struct ethhdr*)pptr;

    memcpy(&eth->h_source, eth_dst, ETH_ALEN);
    memcpy(&eth->h_dest, eth_dst, ETH_ALEN);
    eth->h_proto = htons(ETH_P_IP);

    memcpy(eth_dst_addr.sll_addr, eth_dst, ETH_ALEN);

    pptr += sizeof(struct ethhdr);

    iph = (struct iphdr*)pptr;
    
    iph->ihl = 5;
    iph->version = 4;
    iph->tos = 0;
    iph->tot_len = htons(sizeof(struct iphdr));
    iph->id = htonl(0);
    iph->frag_off = 0;
    iph->ttl = 255;
    iph->protocol = IPPROTO_ICMP;
    iph->check = 0;
    iph->saddr = inet_addr(ipv4_srcaddr);
    iph->daddr = sockin.sin_addr.s_addr;

    if(sendto(
        sockfd, 
        sendbuf, 
        sizeof(struct ethhdr) + ntohs(iph->tot_len), 
        0, 
        (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr)
    ) < 0) perror("sendto");

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    
    uint64_t elapsed_us = elapsed_ns / 1E3;

    printf("ELAPSED %lu us.\n", elapsed_us);

    return 0;
}