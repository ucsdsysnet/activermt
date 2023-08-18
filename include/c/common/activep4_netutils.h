/**
 * @file activep4_netutils.h
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

#ifndef ACTIVEP4_NETUTILS_H
#define ACTIVEP4_NETUTILS_H

//#define DEBUG
#define MSEND           1
#define TRUE            1
#define ETH_P_AP4       0x83B2
#define MMSG_VLEN       512
#define BUFSIZE         2048
#define QUEUELEN        1024
#define IPADDRSIZE      16
#define SNAPLEN_ETH     1500
#define DIVISOR_MMAP    128
#define PACKET_SIZE     64

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>
#include <malloc.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <poll.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/queue.h>
#include <sys/mman.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>

#include "activep4.h"
#include "stats.h"

typedef struct {
    char*           iface_name;
    int             iface_index;
    unsigned char   hwaddr[ETH_ALEN];
    uint32_t        ipv4addr;
} devinfo_t;

typedef struct {
    struct ethhdr*      eth;
    struct iphdr*       iph;
    struct tcphdr*      tcph;
    struct udphdr*      udph;
    activep4_ih*        ap4ih;
    activep4_data_t*    ap4args;
    char*               payload;
    int                 payload_length;
} net_headers_t;

typedef struct {
    char        buf[BUFSIZE];
    int         pktlen;
} tx_pkt_t;

typedef struct {
    int                 qhead;
    int                 qtail;
    tx_pkt_t*           packets[QUEUELEN];
} tx_queue_t;

typedef struct {
    int                     sockfd;
    struct iovec*           rd;
    struct tpacket_req3     req;
    size_t                  ring_size;
    char*                   ring_buffer;
    struct tpacket_stats_v3 stats;
} ring_t;

typedef struct {
    struct iovec*       rx_rd;
    struct iovec*       tx_rd;
    struct tpacket_req3 rx_req;
    struct tpacket_req3 tx_req;
    size_t              rx_ring_size;
    size_t              tx_ring_size;
    char*               rx_ring;
    char*               tx_ring;
} packet_mmap_t;

typedef struct {
    int                 sockfd;
    devinfo_t           dev_info;
    in_addr_t           ipv4_dstaddr;
    unsigned char       eth_dstaddr[ETH_ALEN];
    struct sockaddr_ll  eth_dst_addr;
    packet_mmap_t       ring;
    ring_t              tx_ring;
    ring_t              rx_ring;
} port_config_t;

typedef struct {
    port_config_t*      cfg;
    int                 thread_id;
    int                 frame_offset;
    int                 num_frames;
    uint32_t            tx_pps;
    tx_queue_t          tx_queue;
    void                (*rx_handler)(net_headers_t*);
} thread_config_t;

pthread_mutex_t qlock, rxlock;
stats_t stats;
int is_running;

static inline void init_queue(tx_queue_t* queue) {
    queue->qhead = -1;
    queue->qtail = -1;
}

static inline int is_queue_empty(tx_queue_t* queue) {
    if(queue->qhead == -1) return 1;
    else return 0;
}

static inline int enqueue_pkt(tx_queue_t* queue, tx_pkt_t* pkt) {
    if((queue->qhead >=0 && queue->qtail == QUEUELEN - 1) || (queue->qhead == queue->qtail + 1)) {
        // overflow.
        return -1;
    }
    pthread_mutex_lock(&qlock);
    if(queue->qhead == -1) queue->qhead = 0;
    queue->qtail = (queue->qtail + 1) % QUEUELEN;
    queue->packets[queue->qtail] = pkt;
    pthread_mutex_unlock(&qlock);
    return queue->qtail;
}

static inline int dequeue_pkt(tx_queue_t* queue, tx_pkt_t** pkt) {
    if(queue->qhead == -1) {
        // underflow.
        return -1;
    }
    pthread_mutex_lock(&qlock);
    *pkt = queue->packets[queue->qhead];
    if(queue->qhead == queue->qtail) {
        queue->qhead = -1;
        queue->qtail = -1;
    } else queue->qhead = (queue->qhead + 1) % QUEUELEN;
    pthread_mutex_unlock(&qlock);
    return queue->qhead;
}

static void get_iface(devinfo_t* info, char* dev, int fd) {
    struct ifreq ifr;
    size_t if_name_len = strlen(dev);
    char ip_addr[IPADDRSIZE];
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
    info->iface_index = ifr.ifr_ifindex;
    if(ioctl(fd, SIOCGIFHWADDR, &ifr) < 0) {
        perror("ioctl");
        exit(1);
    }
    memcpy(info->hwaddr, (unsigned char*)ifr.ifr_hwaddr.sa_data, ETH_ALEN);
    ifr.ifr_addr.sa_family = AF_INET;
    if(ioctl(fd, SIOCGIFADDR, &ifr) < 0) {
        perror("ioctl");
        exit(1);
    }
    memcpy(&info->ipv4addr, &((struct sockaddr_in*)&ifr.ifr_addr)->sin_addr.s_addr, sizeof(uint32_t));
    #ifdef DEBUG
    printf("Device %s has iface index %d\n", dev, info->iface_index);
    #endif
    printf("Device %s has hwaddr %.2x:%.2x:%.2x:%.2x:%.2x:%.2x\n", dev, info->hwaddr[0], info->hwaddr[1], info->hwaddr[2], info->hwaddr[3], info->hwaddr[4], info->hwaddr[5]);
    inet_ntop(AF_INET, &info->ipv4addr, ip_addr, IPADDRSIZE);
    printf("Device %s has ipv4 addr %s\n", dev, ip_addr);
}

static int arp_resolve(uint32_t ipv4_dstaddr, char* dev, unsigned char* eth_dstaddr) {
    FILE* fp = fopen("/proc/net/arp", "r");
    char buf[1024];
    unsigned short hwaddr[ETH_ALEN];
    const char* tok;
    uint32_t ip_addr = 0;
    int i;
    while( fgets(buf, 1024, fp) > 0 ) {
        for(tok = strtok(buf, " "); tok && *tok; tok = strtok(NULL, " \n")) {
            if(strcmp(tok, dev) == 0 && ip_addr == ipv4_dstaddr) {
                fclose(fp);
                return 1;
            } 
            if(ip_addr == 0) {
                if(inet_pton(AF_INET, tok, &ip_addr) != 1) ip_addr = 0;
            } else if(strlen(tok) == 17 && sscanf(tok, "%hx:%hx:%hx:%hx:%hx:%hx", &hwaddr[0], &hwaddr[1], &hwaddr[2], &hwaddr[3], &hwaddr[4], &hwaddr[5]) == ETH_ALEN) {
                if(ip_addr == ipv4_dstaddr) {
                    for(i = 0; i < ETH_ALEN; i++) eth_dstaddr[i] = (unsigned char) hwaddr[i];
                } else ip_addr = 0;
            }
        }
    }
    fclose(fp);
    return 0;
}

static inline uint16_t compute_checksum(uint16_t* buf, int num_bytes) {
    uint32_t chksum = 0;
    int i;
    for(i = num_bytes; i > 1; i -= 2) chksum += *buf++;
    if(i == 1) chksum += (*buf & 0xFF00);
    chksum = (chksum >> 16) + (chksum & 0xFFFF);
    chksum = (chksum >> 16) + chksum;
    return (uint16_t)~chksum;
}

static inline int hwaddr_equals(unsigned char* a, unsigned char* b) {
    return ( a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && a[5] == b[5] );
}

static inline void print_hwaddr(unsigned char* hwaddr) {
    printf("%.2x:%.2x:%.2x:%.2x:%.2x:%.2x", hwaddr[0], hwaddr[1], hwaddr[2], hwaddr[3], hwaddr[4], hwaddr[5]);
}

static inline void print_ipv4_addr(uint32_t ipv4addr) {
    char buf[100];
    inet_ntop(AF_INET, &ipv4addr, buf, IPADDRSIZE);
    printf("%s", buf);
}

static inline void print_pktinfo(char* buf, int pktlen) {
    struct ethhdr* eth = (struct ethhdr*) buf;
    int offset = 0;
    if(ntohs(eth->h_proto) == ETH_P_AP4) {
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

static inline int extract_network_headers(char* buf, net_headers_t* hdrs, int pktlen) {
    if(pktlen < sizeof(struct ethhdr)) return -1;
    int offset = 0;
    struct ethhdr* eth = (struct ethhdr*) buf;
    struct iphdr* iph = NULL;
    struct tcphdr* tcph = NULL;
    struct udphdr* udph = NULL;
    activep4_ih* ap4ih = NULL;
    activep4_data_t* ap4args = NULL;
    offset += sizeof(struct ethhdr);
    if(ntohs(eth->h_proto) == ETH_P_AP4) {
        if(pktlen - offset < sizeof(activep4_ih)) return -1;
        ap4ih = (activep4_ih*)(buf + offset);
        offset += sizeof(activep4_ih);
        if(ntohl(ap4ih->SIG) != ACTIVEP4SIG) return -1;
        if(ntohs(ap4ih->flags) & AP4FLAGMASK_OPT_ARGS) {
            ap4args = (activep4_data_t*)(buf + offset);
            offset += sizeof(activep4_data_t);
        }
        offset += get_active_eof(buf + offset, pktlen - offset);
    }
    if(pktlen - offset < sizeof(struct iphdr)) return -1;
    iph = (struct iphdr*)(buf + offset);
    offset += sizeof(struct iphdr);
    if(iph->protocol == IPPROTO_TCP && pktlen - offset >= sizeof(struct tcphdr)) {
        tcph = (struct tcphdr*)(buf + offset);
        offset += tcph->doff * 4;
        hdrs->payload_length = ntohs(iph->tot_len) - (tcph->doff * 4);
    } else if(iph->protocol == IPPROTO_UDP && pktlen - offset >= sizeof(struct udphdr)) {
        udph = (struct udphdr*)(buf + offset);
        offset += sizeof(struct udphdr);
        hdrs->payload_length = ntohs(iph->tot_len) - sizeof(struct udphdr);
    } else {
        return -1;
    }
    hdrs->eth = eth;
    hdrs->iph = iph;
    hdrs->tcph = tcph;
    hdrs->udph = udph;
    hdrs->ap4ih = ap4ih;
    hdrs->ap4args = ap4args;
    hdrs->payload = buf + offset;
    return offset;
}

static inline void busy_wait(uint64_t duration_ns) {
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns = 0;
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}
    while(elapsed_ns < duration_ns) {
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    }
}

/* Default RX/TX. */

void* rx_loop(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;

    fd_set rd_set;
    int maxfd = cfg->sockfd, ret, read_bytes, read_msgs;

    net_headers_t hdrs;

    char recvbuf[BUFSIZE];

    struct mmsghdr msgs[MMSG_VLEN];
    struct iovec iovecs[MMSG_VLEN];
    char bufs[MMSG_VLEN][BUFSIZE+1];

    struct timespec timeout;
    timeout.tv_sec = 0;
    timeout.tv_nsec = 0;

    printf("Starting RX loop ... \n");

    for(int i = 0; i < MMSG_VLEN; i++) {
        iovecs[i].iov_base         = bufs[i];
        iovecs[i].iov_len          = BUFSIZE;
        msgs[i].msg_hdr.msg_iov    = &iovecs[i];
        msgs[i].msg_hdr.msg_iovlen = 1;
    }

    while(TRUE) {
        FD_ZERO(&rd_set);
        FD_SET(cfg->sockfd, &rd_set);

        ret = select(maxfd + 1, &rd_set, NULL, NULL, NULL);
        if(ret < 0 && errno == EINTR) continue;
        if(ret < 0) {
            perror("select()");
            exit(1);
        }

        read_bytes = 0;

        if(FD_ISSET(cfg->sockfd, &rd_set)) {
            if( (read_bytes = read(cfg->sockfd, recvbuf, BUFSIZE)) < 0 ) {
            //if( (read_msgs = recvmmsg(cfg->sockfd, msgs, MMSG_VLEN, 0, &timeout)) < 0 ) {
                perror("read()");
                close(cfg->sockfd);
                exit(1);
            }
            if(read_bytes > sizeof(struct ethhdr)) {
                memset(&hdrs, 0, sizeof(net_headers_t));
                if(extract_network_headers(recvbuf, &hdrs, read_bytes) < 0) {
                    #ifdef DEBUG
                    printf("Error: Invalid packet received.\n");
                    #endif
                    continue;
                }
                if(hwaddr_equals(hdrs.eth->h_dest, cfg->dev_info.hwaddr)) {
                    #ifdef DEBUG
                    printf("[ETH] [%d Bytes] ", read_bytes);
                    #endif
                    pthread_mutex_lock(&lock_alt);
                    stats.count_alt++;
                    pthread_mutex_unlock(&lock_alt);
                    th_cfg->rx_handler(&hdrs);
                } else {
                    #ifdef DEBUG
                    printf("(Unknown) [ETH] [%d Bytes] ", read_bytes);
                    #endif
                }
                #ifdef DEBUG
                print_pktinfo(recvbuf, read_bytes);
                #endif
            }
        }
    }
}

void* tx_loop(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;

    int wrote_bytes;
    tx_pkt_t* pkt;

    printf("Starting TX loop ... \n");

    while(TRUE) {

        if(dequeue_pkt(&th_cfg->tx_queue, &pkt) < 0)
            continue;

        wrote_bytes = 0;

        if( (wrote_bytes = sendto(cfg->sockfd, pkt->buf, pkt->pktlen, 0, (struct sockaddr*)&cfg->eth_dst_addr, sizeof(struct sockaddr_ll))) < 0 ) {
            perror("sendto()");
            close(cfg->sockfd);
            exit(1);
        }
    }
}

void tx_burst(port_config_t* cfg, tx_pkt_t* pkts, int num_pkts) {
    int wrote_bytes = 0;
    for(int i = 0; i < num_pkts; i++) {
        if( (wrote_bytes = sendto(cfg->sockfd, pkts[i].buf, pkts[i].pktlen, 0, (struct sockaddr*)&cfg->eth_dst_addr, sizeof(struct sockaddr_ll))) < 0 ) {
            perror("sendto()");
            close(cfg->sockfd);
            exit(1);
        }
    }
    pthread_mutex_lock(&lock);
    stats.count += num_pkts;
    pthread_mutex_unlock(&lock);
}

int port_init(port_config_t* cfg, char* iface, in_addr_t ipv4_dstaddr) {

    if((cfg->sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(1);
    }

    cfg->dev_info.iface_name = iface;
    get_iface(&cfg->dev_info, iface, cfg->sockfd);

    memset(&cfg->eth_dst_addr, 0, sizeof(struct sockaddr_ll));
    cfg->eth_dst_addr.sll_family = AF_PACKET;
    cfg->eth_dst_addr.sll_ifindex = cfg->dev_info.iface_index;
    cfg->eth_dst_addr.sll_protocol = htons(ETH_P_AP4);
    cfg->eth_dst_addr.sll_halen = ETH_ALEN;

    cfg->ipv4_dstaddr = ipv4_dstaddr;
    if(arp_resolve(ipv4_dstaddr, iface, cfg->eth_dstaddr) == 0) {
        printf("Error: IP address could not be resolved!\n");
        return -1;
    }
    memcpy(&cfg->eth_dst_addr.sll_addr, cfg->eth_dstaddr, ETH_ALEN);
    
    return 0;
}

/* Memory-Mapped RX/TX. */

void* rx_mmap_loop(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;
    ring_t* ring = &cfg->rx_ring;

    size_t frame_idx = 0;
    char* frame_ptr = NULL;
    int frames_per_block = ring->req.tp_block_size / ring->req.tp_frame_size;

    net_headers_t hdrs;

    printf("[INFO] Starting RX thread ... \n");

    while(is_running) {
        frame_idx = (frame_idx + 1) % ring->req.tp_frame_nr;
        //frame_idx = (frame_idx + 1) % th_cfg->num_frames + th_cfg->frame_offset;

        int buffer_idx = frame_idx / frames_per_block;
        char* buffer_ptr = ring->ring_buffer + buffer_idx * ring->req.tp_block_size;

        int frame_idx_diff = frame_idx % frames_per_block;
        frame_ptr = buffer_ptr + frame_idx_diff * ring->req.tp_frame_size;

        struct pollfd fds[1] = {0};
        fds[0].fd = ring->sockfd;
        fds[0].events = POLLIN;

        struct tpacket3_hdr* tphdr = (struct tpacket3_hdr*)frame_ptr;
        while(!(tphdr->tp_status & TP_STATUS_USER) && is_running) {
            if (poll(fds, 1, -1) < 0) {
                perror("poll()");
                exit(1);
            }
        }

        struct sockaddr_ll* addr = (struct sockaddr_ll*)(frame_ptr + TPACKET3_HDRLEN - sizeof(struct sockaddr_ll));
        char* l2content = frame_ptr + tphdr->tp_mac;
        //char* l3content = frame_ptr + tphdr->tp_net;

        struct ethhdr* eth = (struct ethhdr*)l2content;

        if(hwaddr_equals(eth->h_dest, cfg->dev_info.hwaddr)) {
            /*pthread_mutex_lock(&lock_alt);
            stats.count_alt++;
            pthread_mutex_unlock(&lock_alt);*/
            if(extract_network_headers(l2content, &hdrs, tphdr->tp_len) >= 0) {
                th_cfg->rx_handler(&hdrs);
            }
        }

        tphdr->tp_status = TP_STATUS_KERNEL;
    }

    printf("[INFO] RX thread terminated.\n");
}

void* tx_mmap_loop(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;
    ring_t* ring = &cfg->tx_ring;

    fd_set write_fds;

    int bytes_sent, pkts_sent = 0, ret;

    printf("[INFO] Starting TX thread ... \n");

    while(is_running) {
        
        FD_ZERO(&write_fds);
        FD_SET(ring->sockfd, &write_fds);
        
        ret = select(ring->sockfd + 1, NULL, &write_fds, NULL, NULL);
        
        if(ret < 0 && errno == EINTR) continue;
        if(ret < 0) {
            perror("select()");
            exit(1);
        }
        
        if(FD_ISSET(ring->sockfd, &write_fds)) {
            if( (bytes_sent = sendto(ring->sockfd, NULL, 0, MSG_DONTWAIT, (struct sockaddr*)&cfg->eth_dst_addr, sizeof(struct sockaddr_ll))) < 0) {
                //if(errno == EAGAIN || errno == EWOULDBLOCK) continue;
                perror("sendto()");
                exit(1);
            } else if(bytes_sent > 0) {
                /*pkts_sent = bytes_sent / PACKET_SIZE;
                pthread_mutex_lock(&lock);
                stats.count += pkts_sent;
                pthread_mutex_unlock(&lock);*/
            }
        }
    }

    printf("[INFO] TX thread terminated.\n");
}

void tx_mmap_enqueue(port_config_t* cfg, tx_pkt_t* pkts, int num_pkts) {

    ring_t* ring = &cfg->tx_ring;

    struct tpacket3_hdr* tphdr;

    char* frame_ptr = NULL;
    char* block_ptr = NULL;
    int frames_per_block = ring->req.tp_block_size / ring->req.tp_frame_size;
    
    int enqueued = 0;
    num_pkts = ring->req.tp_frame_nr;

    for(int i = 0; i < ring->req.tp_frame_nr && enqueued < num_pkts; i++) {
        block_ptr = ring->ring_buffer + (i / frames_per_block) * ring->req.tp_block_size;
        frame_ptr = block_ptr + (i % frames_per_block) * ring->req.tp_frame_size;
        tphdr = (struct tpacket3_hdr*)frame_ptr;
        if(tphdr->tp_status == TP_STATUS_AVAILABLE) {
            // TODO modify send buffer with data / batch fill and send.
            tphdr->tp_status = TP_STATUS_SEND_REQUEST;
            enqueued++;
        }
    }
}

int tx_setup_buffers(port_config_t* cfg) {

    ring_t* ring = &cfg->tx_ring;

    struct tpacket3_hdr* tphdr;

    char* frame_ptr = NULL;
    char* block_ptr = NULL;
    char* buf;
    int frames_per_block = ring->req.tp_block_size / ring->req.tp_frame_size;

    struct ethhdr* eth;
    struct iphdr* iph;
    struct udphdr* udph;
    char* payload;

    int constructed = 0, payload_length;

    for(int i = 0; i < ring->req.tp_frame_nr; i++) {
        
        block_ptr = ring->ring_buffer + (i / frames_per_block) * ring->req.tp_block_size;
        frame_ptr = block_ptr + (i % frames_per_block) * ring->req.tp_frame_size;

        tphdr = (struct tpacket3_hdr*)frame_ptr;
        if(tphdr->tp_status == TP_STATUS_WRONG_FORMAT) {
            printf("[ERROR] Wrong TP frame format!\n");
            exit(1);
        }
        if(!(tphdr->tp_status == TP_STATUS_AVAILABLE)) continue;

        buf = frame_ptr + TPACKET3_HDRLEN - sizeof(struct sockaddr_ll);
        payload_length = PACKET_SIZE - (sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct udphdr));

        eth = (struct ethhdr*)buf;
        memcpy(&eth->h_source, &cfg->dev_info.hwaddr, ETH_ALEN);
        memcpy(&eth->h_dest, &cfg->eth_dstaddr, ETH_ALEN);
        eth->h_proto = htons(ETH_P_IP);

        iph = (struct iphdr*)(buf + sizeof(struct ethhdr));
        iph->ihl = 5;
        iph->version = 4;
        iph->tos = 0;
        iph->tot_len = htons(sizeof(struct iphdr) + sizeof(struct udphdr) + payload_length);
        iph->id = htonl(0);
        iph->frag_off = 0;
        iph->ttl = 255;
        iph->protocol = IPPROTO_UDP;
        iph->check = 0;
        iph->saddr = cfg->dev_info.ipv4addr;
        iph->daddr = cfg->ipv4_dstaddr;

        iph->check = compute_checksum((uint16_t*)iph, sizeof(struct iphdr));

        udph = (struct udphdr*)(buf + sizeof(struct ethhdr) + sizeof(struct iphdr));
        udph->source = htons(1234);
        udph->dest = htons(1234);
        udph->len = htons(sizeof(struct udphdr) + payload_length);
        udph->check = htons(0);

        payload = buf + sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct udphdr);
        memset(payload, 0, payload_length);

        tphdr->tp_len = PACKET_SIZE;
        tphdr->tp_status = TP_STATUS_SEND_REQUEST;

        constructed++;
    }

    #ifdef DEBUG
    pthread_mutex_lock(&lock);
    stats.count += constructed;
    pthread_mutex_unlock(&lock);
    #endif

    return constructed;
}

void setup_rx_ring(ring_t* ring) {

    if((ring->sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(1);
    }

    int version = TPACKET_V3;
    if((setsockopt(ring->sockfd, SOL_PACKET, PACKET_VERSION, &version, sizeof(version))) < 0) {
        perror("setsockopt(PACKET_VERSION)");
        exit(1);
    }

    memset(&ring->req, 0, sizeof(struct tpacket_req3));
    ring->req.tp_frame_size = TPACKET_ALIGN(TPACKET_HDRLEN + ETH_HLEN) + TPACKET_ALIGN(SNAPLEN_ETH);
    ring->req.tp_block_size = sysconf(_SC_PAGESIZE);
    while(ring->req.tp_block_size < ring->req.tp_frame_size)
        ring->req.tp_block_size <<= 1;
    ring->req.tp_block_nr = sysconf(_SC_PHYS_PAGES) * sysconf(_SC_PAGESIZE) / (DIVISOR_MMAP * ring->req.tp_block_size);
    ring->req.tp_frame_nr = (ring->req.tp_block_size / ring->req.tp_frame_size) * ring->req.tp_block_nr;
    // ring->req.tp_retire_blk_tov = 60;
    // ring->req.tp_feature_req_word = TP_FT_REQ_FILL_RXHASH;
    ring->ring_size = ring->req.tp_block_size * ring->req.tp_block_nr;

    if(setsockopt(ring->sockfd, SOL_PACKET, PACKET_RX_RING, &ring->req, sizeof(ring->req)) < 0) {
        perror("setsockopt(PACKET_RX_RING)");
        exit(1);
    }

    if((ring->ring_buffer = mmap(0, ring->ring_size, PROT_READ|PROT_WRITE, MAP_SHARED, ring->sockfd, 0)) == MAP_FAILED) {
        perror("mmap()");
        exit(1);
    }

    if((ring->rd = malloc(ring->req.tp_block_nr * sizeof(struct iovec))) == NULL) {
        perror("malloc()");
        exit(1);
    }

    for(int i = 0; i < ring->req.tp_block_nr; i++) {
        ring->rd[i].iov_base = ring->ring_buffer + (i * ring->req.tp_block_size);
        ring->rd[i].iov_len = ring->req.tp_block_size;
    }

    printf("[INFO] Memory mapped I/O buffers set for %u RX frames.\n", ring->req.tp_frame_nr);
}

void setup_tx_ring(ring_t* ring, int iface_index) {

    if((ring->sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(1);
    }

    int version = TPACKET_V3;
    if((setsockopt(ring->sockfd, SOL_PACKET, PACKET_VERSION, &version, sizeof(version))) < 0) {
        perror("setsockopt(PACKET_VERSION)");
        exit(1);
    }

    memset(&ring->req, 0, sizeof(struct tpacket_req3));
    ring->req.tp_frame_size = TPACKET_ALIGN(TPACKET3_HDRLEN + ETH_HLEN) + TPACKET_ALIGN(SNAPLEN_ETH);
    ring->req.tp_block_size = sysconf(_SC_PAGESIZE);
    while(ring->req.tp_block_size < ring->req.tp_frame_size)
        ring->req.tp_block_size <<= 1;
    ring->req.tp_block_nr = sysconf(_SC_PHYS_PAGES) * sysconf(_SC_PAGESIZE) / (DIVISOR_MMAP * ring->req.tp_block_size);
    ring->req.tp_frame_nr = (ring->req.tp_block_size / ring->req.tp_frame_size) * ring->req.tp_block_nr;
    ring->ring_size = ring->req.tp_block_size * ring->req.tp_block_nr;

    if(setsockopt(ring->sockfd, SOL_PACKET, PACKET_TX_RING, &ring->req, sizeof(ring->req)) < 0) {
        perror("setsockopt(PACKET_TX_RING)");
        exit(1);
    }

    /*int one = 1;
    if(setsockopt(ring->sockfd, SOL_PACKET, PACKET_QDISC_BYPASS, &one, sizeof(one)) < 0) {
        perror("setsocketopt(PACKET_QDISC_BYPASS)");
        exit(1);
    }*/

    struct sockaddr_ll ll;
    ll.sll_family = PF_PACKET;
    ll.sll_protocol = htons(ETH_P_ALL);
    ll.sll_ifindex = iface_index;
    ll.sll_hatype = 0;
    ll.sll_pkttype = 0;
    ll.sll_halen = 0;

    if(bind(ring->sockfd, (struct sockaddr*)&ll, sizeof(struct sockaddr_ll)) < 0) {
        perror("bind()");
        exit(1);
    }

    if((ring->ring_buffer = mmap(0, ring->ring_size, PROT_READ|PROT_WRITE, MAP_SHARED, ring->sockfd, 0)) == MAP_FAILED) {
        perror("mmap()");
        exit(1);
    }

    if((ring->rd = malloc(ring->req.tp_block_nr * sizeof(struct iovec))) == NULL) {
        perror("malloc()");
        exit(1);
    }

    for(int i = 0; i < ring->req.tp_block_nr; i++) {
        ring->rd[i].iov_base = ring->ring_buffer + (i * ring->req.tp_block_size);
        ring->rd[i].iov_len = ring->req.tp_block_size;
    }

    printf("[INFO] Memory mapped I/O buffers set for %u TX frames.\n", ring->req.tp_frame_nr);
}

void port_init_mmap(port_config_t* cfg) {

    if((cfg->sockfd = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(1);
    }

    get_iface(&cfg->dev_info, cfg->dev_info.iface_name, cfg->sockfd);

    packet_mmap_t* ring = &cfg->ring;

    int version = TPACKET_V1;
    if((setsockopt(cfg->sockfd, SOL_PACKET, PACKET_VERSION, &version, sizeof(version))) < 0) {
        perror("setsockopt(PACKET_VERSION)");
        exit(1);
    }

    memset(&ring->rx_req, 0, sizeof(struct tpacket_req3));
    ring->rx_req.tp_frame_size = TPACKET_ALIGN(TPACKET_HDRLEN + ETH_HLEN) + TPACKET_ALIGN(SNAPLEN_ETH);
    ring->rx_req.tp_block_size = sysconf(_SC_PAGESIZE);
    while(ring->rx_req.tp_block_size < ring->rx_req.tp_frame_size)
        ring->rx_req.tp_block_size <<= 1;
    ring->rx_req.tp_block_nr = sysconf(_SC_PHYS_PAGES) * sysconf(_SC_PAGESIZE) / (512 * ring->rx_req.tp_block_size);
    ring->rx_req.tp_frame_nr = (ring->rx_req.tp_block_size / ring->rx_req.tp_frame_size) * ring->rx_req.tp_block_nr;
    // ring->rx_req.tp_retire_blk_tov = 60;
    // ring->rx_req.tp_feature_req_word = TP_FT_REQ_FILL_RXHASH;

    if(setsockopt(cfg->sockfd, SOL_PACKET, PACKET_RX_RING, &ring->rx_req, sizeof(ring->rx_req)) < 0) {
        perror("setsockopt(PACKET_RX_RING)");
        exit(1);
    }

    struct sockaddr_ll ll;
    ll.sll_family = PF_PACKET;
    ll.sll_protocol = htons(ETH_P_ALL);
    ll.sll_ifindex = cfg->dev_info.iface_index;
    ll.sll_hatype = 0;
    ll.sll_pkttype = 0;
    ll.sll_halen = 0;

    if(bind(cfg->sockfd, (struct sockaddr*)&ll, sizeof(struct sockaddr_ll)) < 0) {
        perror("bind()");
        exit(1);
    }

    memset(&ring->tx_req, 0, sizeof(struct tpacket_req3));
    ring->tx_req.tp_frame_size = TPACKET_ALIGN(TPACKET_HDRLEN + ETH_HLEN) + TPACKET_ALIGN(SNAPLEN_ETH);
    ring->tx_req.tp_block_size = sysconf(_SC_PAGESIZE);
    while (ring->tx_req.tp_block_size < ring->tx_req.tp_frame_size)
        ring->tx_req.tp_block_size <<= 1;
    ring->tx_req.tp_block_nr = sysconf(_SC_PHYS_PAGES) * sysconf(_SC_PAGESIZE) / (512 * ring->tx_req.tp_block_size);
    ring->tx_req.tp_frame_nr = (ring->tx_req.tp_block_size * ring->tx_req.tp_block_nr) / ring->tx_req.tp_frame_size;

    if (setsockopt(cfg->sockfd, SOL_PACKET, PACKET_TX_RING, &ring->tx_req, sizeof(ring->tx_req)) < 0) {
        perror("setsockopt(PACKET_TX_RING)");
        exit(1);
    }

    ring->rx_ring_size = ring->rx_req.tp_block_size * ring->rx_req.tp_block_nr;
    ring->tx_ring_size = ring->tx_req.tp_block_size * ring->tx_req.tp_block_nr;
    if((ring->rx_ring = mmap(0, ring->rx_ring_size + ring->tx_ring_size, PROT_READ|PROT_WRITE, MAP_SHARED, cfg->sockfd, 0)) == MAP_FAILED) {
        perror("mmap()");
        exit(1);
    }
    ring->tx_ring = ring->rx_ring + ring->rx_ring_size;

    if((ring->rx_rd = malloc(ring->rx_req.tp_block_nr * sizeof(struct iovec))) == NULL) {
        perror("malloc()");
        exit(1);
    }
    for(int i = 0; i < ring->rx_req.tp_block_nr; i++) {
        ring->rx_rd[i].iov_base = ring->rx_ring + (i * ring->rx_req.tp_block_size);
        ring->rx_rd[i].iov_len = ring->rx_req.tp_block_size;
    }

    if((ring->tx_rd = malloc(ring->tx_req.tp_block_nr * sizeof(struct iovec))) == NULL) {
        perror("malloc()");
        exit(1);
    }
    for(int i = 0; i < ring->tx_req.tp_block_nr; i++) {
        ring->tx_rd[i].iov_base = ring->rx_ring + (i * ring->tx_req.tp_block_size);
        ring->tx_rd[i].iov_len = ring->tx_req.tp_block_size;
    }

    printf("[INFO] Memory mapped I/O buffers set for %u RX/TX frames.", ring->tx_req.tp_frame_nr);
}

void port_teardown_mmap(port_config_t* cfg) {

    munmap(cfg->rx_ring.ring_buffer, cfg->rx_ring.ring_size);
    munmap(cfg->tx_ring.ring_buffer, cfg->tx_ring.ring_size);

    free(cfg->rx_ring.rd);
    free(cfg->tx_ring.rd);

    close(cfg->rx_ring.sockfd);
    close(cfg->tx_ring.sockfd);

    printf("[INFO] Port teardown complete.\n");
}

#endif