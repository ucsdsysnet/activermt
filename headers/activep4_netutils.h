#ifndef ACTIVEP4_NETUTILS_H
#define ACTIVEP4_NETUTILS_H

#define MSEND           1
#define TRUE            1
#define ETH_P_AP4       0x83B2
#define MMSG_VLEN       512
#define BUFSIZE         2048
#define QUEUELEN        1024
#define IPADDRSIZE      16
#define SNAPLEN_ETH     1500

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
    int                 fd;
    size_t              rx_ring_size;
    char*               rx_ring;
    struct tpacket_req  req;
    size_t              frames_per_buffer;
    int                 num_blocks;
} packet_mmap_t;

typedef struct {
    int                 sockfd;
    devinfo_t           dev_info;
    in_addr_t           ipv4_dstaddr;
    unsigned char       eth_dstaddr[ETH_ALEN];
    struct sockaddr_ll  eth_dst_addr;
    packet_mmap_t       pmmap;
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

static inline void print_pktinfo(char* buf) {
    struct ethhdr* eth = (struct ethhdr*) buf;
    int offset = 0;
    if(ntohs(eth->h_proto) == ETH_P_AP4) {
        offset += sizeof(activep4_ih);
        if(ntohs(((activep4_ih*)&eth[1])->flags) & AP4FLAGMASK_OPT_ARGS) offset += sizeof(activep4_data_t);
        offset += get_active_eof(buf + sizeof(struct ethhdr) + offset);
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

static inline int extract_network_headers(char* buf, net_headers_t* hdrs) {
    int offset = 0;
    struct ethhdr* eth = (struct ethhdr*) buf;
    struct iphdr* iph = NULL;
    struct tcphdr* tcph = NULL;
    struct udphdr* udph = NULL;
    activep4_ih* ap4ih = NULL;
    activep4_data_t* ap4args = NULL;
    offset += sizeof(struct ethhdr);
    if(ntohs(eth->h_proto) == ETH_P_AP4) {
        ap4ih = (activep4_ih*)(buf + offset);
        offset += sizeof(activep4_ih);
        if(ntohl(ap4ih->SIG) != ACTIVEP4SIG) return -1;
        if(ntohs(ap4ih->flags) & AP4FLAGMASK_OPT_ARGS) {
            ap4args = (activep4_data_t*)(buf + offset);
            offset += sizeof(activep4_data_t);
        }
        offset += get_active_eof(buf + offset);
    }
    iph = (struct iphdr*)(buf + offset);
    offset += sizeof(struct iphdr);
    if(iph->protocol == IPPROTO_TCP) {
        tcph = (struct tcphdr*)(buf + offset);
        offset += tcph->doff * 4;
        hdrs->payload_length = ntohs(iph->tot_len) - (tcph->doff * 4);
    } else if(iph->protocol == IPPROTO_UDP) {
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

void* rx_mmap_loop(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;
    packet_mmap_t* mmapcfg = &cfg->pmmap;

    size_t frame_idx = 0;
    char* frame_ptr = NULL;

    net_headers_t hdrs;

    while(TRUE) {
        //frame_idx = (frame_idx + 1) % mmapcfg->req.tp_frame_nr;
        frame_idx = (frame_idx + 1) % th_cfg->num_frames + th_cfg->frame_offset;

        int buffer_idx = frame_idx / mmapcfg->frames_per_buffer;
        char* buffer_ptr = mmapcfg->rx_ring + buffer_idx * mmapcfg->req.tp_block_size;

        int frame_idx_diff = frame_idx % mmapcfg->frames_per_buffer;
        frame_ptr = buffer_ptr + frame_idx_diff * mmapcfg->req.tp_frame_size;

        struct pollfd fds[1] = {0};
        fds[0].fd = mmapcfg->fd;
        fds[0].events = POLLIN;

        struct tpacket_hdr* tphdr = (struct tpacket_hdr*)frame_ptr;
        while(!(tphdr->tp_status & TP_STATUS_USER)) {
            if (poll(fds, 1, -1) < 0) {
                perror("poll()");
                exit(1);
            }
        }

        struct sockaddr_ll* addr = (struct sockaddr_ll*)(frame_ptr + TPACKET_HDRLEN - sizeof(struct sockaddr_ll));
        char* l2content = frame_ptr + tphdr->tp_mac;
        //char* l3content = frame_ptr + tphdr->tp_net;

        struct ethhdr* eth = (struct ethhdr*)l2content;

        if(hwaddr_equals(eth->h_dest, cfg->dev_info.hwaddr)) {
            pthread_mutex_lock(&lock_alt);
            stats.count_alt++;
            pthread_mutex_unlock(&lock_alt);
            if(extract_network_headers(l2content, &hdrs) >= 0) {
                th_cfg->rx_handler(&hdrs);
            }
        }

        tphdr->tp_status = TP_STATUS_KERNEL;
    }
}

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
                if(extract_network_headers(recvbuf, &hdrs) < 0) {
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
                print_pktinfo(recvbuf);
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

    packet_mmap_t* mmapcfg = &cfg->pmmap;

    mmapcfg->fd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if(mmapcfg->fd < 0) {
        perror("socket()");
        exit(1);
    }

    //mmapcfg->fd = cfg->sockfd;

    int version = TPACKET_V1;
    if((setsockopt(mmapcfg->fd, SOL_PACKET, PACKET_VERSION, &version, sizeof(version))) < 0) {
        perror("setsockopt()");
        exit(1);
    }

    memset(&mmapcfg->req, 0, sizeof(struct tpacket_req));
    mmapcfg->req.tp_frame_size = TPACKET_ALIGN(TPACKET_HDRLEN + ETH_HLEN) + TPACKET_ALIGN(SNAPLEN_ETH);

    mmapcfg->req.tp_block_size = sysconf(_SC_PAGESIZE);
    while (mmapcfg->req.tp_block_size < mmapcfg->req.tp_frame_size) {
        mmapcfg->req.tp_block_size <<= 1;
    }

    mmapcfg->req.tp_block_nr = sysconf(_SC_PHYS_PAGES) * sysconf(_SC_PAGESIZE) / (128 * mmapcfg->req.tp_block_size);

    mmapcfg->frames_per_buffer = mmapcfg->req.tp_block_size / mmapcfg->req.tp_frame_size;
    mmapcfg->req.tp_frame_nr = mmapcfg->req.tp_block_nr * mmapcfg->frames_per_buffer;

    if (setsockopt(mmapcfg->fd, SOL_PACKET, PACKET_RX_RING, &mmapcfg->req, sizeof(mmapcfg->req)) < 0) {
        perror("setsockopt()");
        exit(1);
    }

    mmapcfg->rx_ring_size = mmapcfg->req.tp_block_nr * mmapcfg->req.tp_block_size;
    mmapcfg->rx_ring = mmap(0, mmapcfg->rx_ring_size, PROT_READ|PROT_WRITE, MAP_SHARED, mmapcfg->fd, 0);

    mmapcfg->num_blocks = mmapcfg->req.tp_block_nr;

    printf("Set up ring buffer with %lu frames.\n", mmapcfg->frames_per_buffer * mmapcfg->req.tp_block_nr);
    
    return 0;
}

#endif