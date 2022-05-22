#ifndef ACTIVEP4_TUNNEL_H
#define ACTIVEP4_TUNNEL_H

#define BUFSIZE         16384
#define MAXARP          65536
#define ARPMASK         0x0000FFFF
#define TUN_NETMASK     0x00FFFFFF
#define IPADDRSIZE      16
#define TUNOFFSET       4
#define CRCPOLY_DNP     0x3D65
#define ETHTYPE_AP4     0x83B2

#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <linux/if_tun.h>

#include "activep4.h"

typedef struct {
    int             iface_index;
    unsigned char   hwaddr[ETH_ALEN];
    uint32_t        ipv4addr;
} devinfo_t;

typedef struct {
    uint32_t        ip_addr;
    unsigned char   eth_addr[ETH_ALEN];
} arp_entry_t;

typedef struct {
    uint32_t    ipv4_src_addr;
    uint32_t    ipv4_dst_addr;
    uint8_t     ipv4_protocol;
    uint16_t    tcp_src_port;
    uint16_t    tcp_dst_port;
} inet_5tuple_t;

int active_filter_udp_tx(struct iphdr* iph, struct udphdr* udph, char* buf);

int active_filter_tcp_tx(struct iphdr* iph, struct tcphdr* tcph, char* buf);

void active_filter_udp_rx(struct iphdr* iph, struct udphdr* udph, activep4_ih* ap4ih);

void active_filter_tcp_rx(struct iphdr* iph, struct tcphdr* tcph, activep4_ih* ap4ih);

static inline int hwaddr_equals(unsigned char* a, unsigned char* b) {
    return ( a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && a[5] == b[5] );
}

static inline void print_hwaddr(unsigned char* hwaddr) {
    printf("hwaddr: %.2x:%.2x:%.2x:%.2x:%.2x:%.2x\n", hwaddr[0], hwaddr[1], hwaddr[2], hwaddr[3], hwaddr[4], hwaddr[5]);
}

static inline uint16_t hash_5tuple(inet_5tuple_t* conn) {
    uint16_t crc16 = 0;
    int i, j, num_bytes = sizeof(inet_5tuple_t);
    char* buf = (char*)malloc(num_bytes);
    memcpy(buf, (char*)conn, num_bytes);
    for(i = 0; i < num_bytes; i++) {
        crc16 = crc16 ^ (buf[i] << 8);
        for(j = 0; j < 8; j++) {
            if(crc16 & 0x8000) crc16 = (crc16 << 1) ^ CRCPOLY_DNP;
            else crc16 = crc16 << 1;
        }
    }
    return crc16;
}

static inline uint16_t cksum_5tuple(inet_5tuple_t* conn) {
    return ~(
        (uint16_t)(conn->ipv4_src_addr & 0xFFFF) +
        (uint16_t)(conn->ipv4_src_addr & 0xFFFF >> 16) + 
        (uint16_t)(conn->ipv4_dst_addr & 0xFFFF) +
        (uint16_t)(conn->ipv4_dst_addr & 0xFFFF >> 16) +
        (uint16_t)conn->ipv4_protocol +
        conn->tcp_src_port +
        conn->tcp_dst_port
    );
}

static inline uint16_t update_checksum(uint16_t chksum, uint32_t old_ipv4_dstaddr, uint32_t new_ipv4_dstaddr) {
    uint32_t diffsum = 0;
    diffsum += chksum;
    diffsum += -(uint16_t)(old_ipv4_dstaddr & 0xFFFF);
    diffsum += -(uint16_t)(old_ipv4_dstaddr >> 16);
    diffsum += (uint16_t)(new_ipv4_dstaddr & 0xFFFF);
    diffsum += (uint16_t)(new_ipv4_dstaddr >> 16);
    diffsum = (diffsum >> 16) + (diffsum & 0xFFFF);
    diffsum = (diffsum >> 16) + diffsum;
    return (uint16_t)~diffsum;
}

static int allocate_tun(char* dev, int flags) {
    struct ifreq ifr;
    int fd, err;
    char* tundev = "/dev/net/tun";

    if( (fd = open(tundev, O_RDWR)) < 0 ) return fd;

    memset(&ifr, 0, sizeof(ifr));

    ifr.ifr_flags = flags;

    if(*dev) strncpy(ifr.ifr_name, dev, IFNAMSIZ);

    if( (err = ioctl(fd, TUNSETIFF, (void*)&ifr)) < 0 ) {
        close(fd);
        return err;
    }

    strcpy(dev, ifr.ifr_name);

    return fd;
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

static int get_arp_cache(arp_entry_t* arp_cache) {
    FILE* fp = fopen("/proc/net/arp", "r");
    char buf[1024];
    unsigned short hwaddr[ETH_ALEN];
    const char* tok;
    uint32_t ip_addr = 0;
    uint32_t entry_idx = 0;
    int num_entries = 0, i;
    while( fgets(buf, 1024, fp) > 0 ) {
        for(tok = strtok(buf, " "); tok && *tok; tok = strtok(NULL, " ")) {
            if(ip_addr == 0) {
                if(inet_pton(AF_INET, tok, &ip_addr) != 1) ip_addr = 0;
            } else {
                if(strlen(tok) == 17 && sscanf(tok, "%hx:%hx:%hx:%hx:%hx:%hx", &hwaddr[0], &hwaddr[1], &hwaddr[2], &hwaddr[3], &hwaddr[4], &hwaddr[5]) == ETH_ALEN) {
                    entry_idx = ntohl(ip_addr) & ARPMASK;
                    arp_cache[entry_idx].ip_addr = ip_addr;
                    for(i = 0; i < ETH_ALEN; i++) arp_cache[entry_idx].eth_addr[i] = (unsigned char) hwaddr[i];
                    ip_addr = 0;
                    num_entries++;
                    #ifdef DEBUG
                    inet_ntop(AF_INET, &arp_cache[entry_idx].ip_addr, buf, IPADDRSIZE);
                    printf("<ARP> (%d) %s has ", entry_idx, buf);
                    print_hwaddr(arp_cache[entry_idx].eth_addr);
                    #endif
                }
            }
        }
    }
    fclose(fp);
    #ifdef DEBUG
    printf("Read %d ARP entries from cache.\n", num_entries);
    #endif
    return num_entries;
}

static void run_tunnel(char* tun_iface, char* eth_iface, char* dst_eth_addr) {

    struct sockaddr_in sin, tin;

    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr(dst_eth_addr);

    tin.sin_family = AF_INET;

    char dev[IFNAMSIZ];

    strcpy(dev, tun_iface);
    
    int tunfd = allocate_tun(dev, IFF_TUN);

    if(tunfd < 0) {
        perror("Unable to get TUN interface.");
        exit(1);
    }

    int conn = socket(PF_INET, SOCK_RAW, IPPROTO_RAW);
    int sockfd;
    if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }

    devinfo_t dev_info, tun_info;

    get_iface(&dev_info, eth_iface, sockfd);

    int sock_tun;
    if((sock_tun = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }
    get_iface(&tun_info, tun_iface, sock_tun);
    close(sock_tun);

    arp_entry_t arp_cache[MAXARP];

    get_arp_cache(arp_cache);

    uint16_t ipv4_nat[65536];

    int i;
    for(i = 0; i < 65536; i++) ipv4_nat[i] = 0;

    struct sockaddr_ll addr = {0};
    addr.sll_family = AF_PACKET;
    addr.sll_ifindex = dev_info.iface_index;
    addr.sll_protocol = htons(ETH_P_ALL);

    if(bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("bind");
        exit(1);
    }

    struct sockaddr_ll eth_dst_addr = {0};
    eth_dst_addr.sll_family = AF_PACKET;
    eth_dst_addr.sll_ifindex = dev_info.iface_index;
    eth_dst_addr.sll_protocol = htons(ETHTYPE_AP4);
    eth_dst_addr.sll_halen = ETH_ALEN;

    int maxfd = (sockfd > tunfd) ? sockfd : tunfd;

    fd_set rd_set;
    char* pptr;

    struct ethhdr*  eth;
    struct iphdr*   iph;
    struct udphdr*  udph;
    struct tcphdr*  tcph;

    activep4_ih* ap4ih;

    uint16_t ap4_flags, pkt_size, ip_masked_src, ip_masked_dst;

    char ipaddr[IPADDRSIZE];

    uint32_t arp_idx;

    int read_bytes, ap4_offset, ret, offset;
    char recvbuf[BUFSIZE], sendbuf[BUFSIZE];

    while(TRUE) {
        
        FD_ZERO(&rd_set);
        FD_SET(sockfd, &rd_set);
        FD_SET(tunfd, &rd_set);
        ret = select(maxfd + 1, &rd_set, NULL, NULL, NULL);

        if(ret < 0 && errno == EINTR) continue;

        if(ret < 0) {
            perror("select");
            exit(1);
        }

        if(FD_ISSET(sockfd, &rd_set)) {
            read_bytes = read(sockfd, recvbuf, sizeof(recvbuf));
            eth = (struct ethhdr*)recvbuf;
            if(hwaddr_equals(eth->h_dest, dev_info.hwaddr)) {
                #ifdef DEBUG
                printf("<< FRAME: %d bytes from protocol 0x%hx\n", read_bytes, ntohs(eth->h_proto));
                #endif
                if(ntohs(eth->h_proto) == ETHTYPE_AP4 && read_bytes > 34) {
                    offset = 0;
                    ap4ih = NULL;
                    if(is_activep4(recvbuf + sizeof(struct ethhdr))) {
                        ap4ih = (activep4_ih*) (recvbuf + sizeof(struct ethhdr));
                        ap4_flags = ntohs(ap4ih->flags);
                        if(((ap4_flags & AP4FLAGS_DONE) >> 8) == 0) offset = get_active_eof(recvbuf + sizeof(struct ethhdr) + sizeof(activep4_ih));
                        offset += sizeof(activep4_ih);
                        iph = (struct iphdr*) (recvbuf + sizeof(struct ethhdr) + offset);
                        if((iph->daddr & TUN_NETMASK) == (tun_info.ipv4addr & TUN_NETMASK)) {
                            #ifdef DEBUG
                            inet_ntop(AF_INET, &tun_info.ipv4addr, ipaddr, IPADDRSIZE);
                            printf("== RELAY: %d bytes to %s\n", ntohs(iph->tot_len), ipaddr);
                            #endif
                            if(iph->protocol == IPPROTO_TCP) {
                                tcph = (struct tcphdr*) (recvbuf + sizeof(struct ethhdr) + offset + sizeof(struct iphdr));
                                active_filter_tcp_rx(iph, tcph, ap4ih);
                            } else if(iph->protocol == IPPROTO_UDP) {
                                udph = (struct udphdr*) (recvbuf + sizeof(struct ethhdr) + offset + sizeof(struct iphdr));
                                active_filter_udp_rx(iph, udph, ap4ih);
                            }
                            memset(sendbuf, 0, BUFSIZE);
                            memcpy(sendbuf, recvbuf + sizeof(struct ethhdr) + offset, ntohs(iph->tot_len));
                            tin.sin_addr.s_addr = (in_addr_t)tun_info.ipv4addr;
                            if( sendto(conn, sendbuf, ntohs(iph->tot_len), 0, (struct sockaddr*)&tin, sizeof(tin)) < 0 )
                            perror("sendto");
                        } else {
                            printf("xx Destination unknown!\n");
                        }
                    } else {
                        // kernel will route
                    }
                }
            }
        }

        if(FD_ISSET(tunfd, &rd_set)) {
            read_bytes = read(tunfd, recvbuf, sizeof(recvbuf));
            if(read_bytes < 0) {
                perror("Unable to read from TUN interface");
                close(tunfd);
                exit(1);
            } else {
                memset(sendbuf, 0, BUFSIZE);
                iph = (struct iphdr*) (recvbuf + TUNOFFSET);
                pptr = sendbuf;
                ap4_offset = 0;
                eth = (struct ethhdr*)pptr;
                inet_ntop(AF_INET, &sin.sin_addr.s_addr, ipaddr, IPADDRSIZE);
                arp_idx = ntohl(sin.sin_addr.s_addr) & ARPMASK;
                memcpy(&eth->h_source, &dev_info.hwaddr, ETH_ALEN);
                memcpy(&eth->h_dest, arp_cache[arp_idx].eth_addr, ETH_ALEN);
                memcpy(eth_dst_addr.sll_addr, arp_cache[arp_idx].eth_addr, ETH_ALEN);
                eth->h_proto = htons(ETHTYPE_AP4);
                pptr += sizeof(struct ethhdr);
                if(iph->protocol == IPPROTO_TCP) {
                    tcph = (struct tcphdr*) (recvbuf + TUNOFFSET + sizeof(struct iphdr));
                    ap4_offset = active_filter_tcp_tx(iph, tcph, pptr);
                    pptr += ap4_offset;
                } else if(iph->protocol == IPPROTO_UDP) {
                    udph = (struct udphdr*) (recvbuf + TUNOFFSET + sizeof(struct iphdr));
                    ap4_offset = active_filter_udp_tx(iph, udph, pptr);
                    pptr += ap4_offset;
                }
                memcpy(pptr, recvbuf + TUNOFFSET, ntohs(iph->tot_len));
                if( sendto(sockfd, sendbuf, sizeof(struct ethhdr) + ntohs(iph->tot_len) + ap4_offset, 0, (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr)) < 0 )
                    perror("sendto");
                #ifdef DEBUG
                inet_ntop(AF_INET, &iph->daddr, ipaddr, IPADDRSIZE);
                printf(">> FRAME: sending %d bytes to %s with IP length %d\n", read_bytes, ipaddr, ntohs(iph->tot_len));
                #endif
            }
        }
    }
}

#endif