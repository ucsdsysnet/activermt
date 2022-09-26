//#define DEBUG       1
#define TRUE        1
#define TUNOFFSET   0
#define BUFSIZE     4096
#define IPADDRSIZE  16

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

typedef struct {
    int             iface_index;
    unsigned char   hwaddr[ETH_ALEN];
    uint32_t        ipv4addr;
} devinfo_t;

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
    struct iphdr* iph = (struct iphdr*) (buf + sizeof(struct ethhdr));
    printf("[%d] [", eth->h_proto);
    print_ipv4_addr(iph->saddr);
    printf(" -> ");
    print_ipv4_addr(iph->daddr);
    printf("] [");
    print_hwaddr(eth->h_source);
    printf(" -> ");
    print_hwaddr(eth->h_dest);
    printf("]\n");
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

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage: %s <tun_iface> <eth_iface>\n", argv[0]);
        exit(1);
    }

    char* tun_iface = argv[1];
    char* eth_iface = argv[2];

    struct sockaddr_in tin;

    tin.sin_family = AF_INET;

    int tunfd = allocate_tun(tun_iface, IFF_TUN | IFF_NO_PI);

    if(tunfd < 0) {
        perror("Unable to get TUN interface");
        exit(1);
    }

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
    eth_dst_addr.sll_protocol = htons(ETH_P_IP);
    eth_dst_addr.sll_halen = ETH_ALEN;

    int maxfd = (sockfd > tunfd) ? sockfd : tunfd;
    fd_set rd_set;

    int read_bytes, ret, wrote_bytes, eth_dst_resolved = 0;
    uint32_t ipv4_dstaddr;
    char sendbuf[BUFSIZE];
    char* recvbuf = sendbuf + sizeof(struct ethhdr);

    memset(sendbuf, 0, BUFSIZE);

    struct ethhdr*  eth = (struct ethhdr*) sendbuf;
    struct iphdr*   iph;

    memcpy(&eth->h_source, &dev_info.hwaddr, ETH_ALEN);
    eth->h_proto = htons(ETH_P_IP);

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

        read_bytes = 0;
        wrote_bytes = 0;

        // ETH iface.
        if(FD_ISSET(sockfd, &rd_set)) {
            if( (read_bytes = read(sockfd, recvbuf, BUFSIZE)) < 0 ) {
                perror("read()");
                close(sockfd);
                exit(1);
            }
            if(read_bytes > (sizeof(struct ethhdr) + sizeof(struct iphdr))) {
                eth = (struct ethhdr*)(recvbuf + TUNOFFSET);
                iph = (struct iphdr*)(recvbuf + TUNOFFSET + sizeof(struct ethhdr));
                if(hwaddr_equals(eth->h_dest, dev_info.hwaddr)) {
                    #ifdef DEBUG
                    printf("[ETH] [%d Bytes] ", read_bytes);
                    #endif
                    /*if( (wrote_bytes = write(tunfd, recvbuf, read_bytes)) < 0 ) {
                        perror("write()");
                        close(sockfd);
                        exit(1);
                    }*/
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

        read_bytes = 0;
        wrote_bytes = 0;

        // TUN iface.
        if(FD_ISSET(tunfd, &rd_set)) {
            if( (read_bytes = read(tunfd, recvbuf, BUFSIZE)) < 0 ) {
                perror("read()");
                close(tunfd);
                exit(1);
            }
            #ifdef DEBUG
            if(read_bytes > TUNOFFSET) {
                printf("[TUN] [%d Bytes] ", read_bytes);
                print_pktinfo(sendbuf);
            }
            #endif
            iph = (struct iphdr*)(recvbuf + TUNOFFSET);
            if(eth_dst_resolved == 0) {
                // Assuming (/24) mapping: x.x.x.y -> z.z.z.y
                ipv4_dstaddr = (iph->daddr & 0xFF000000) | (dev_info.ipv4addr & 0x00FFFFFF);
                if( (eth_dst_resolved = arp_resolve(ipv4_dstaddr, eth_iface, eth->h_dest)) == 0 ) {
                    printf("((ARP)) resolution error: ");
                    print_ipv4_addr(ipv4_dstaddr);
                    printf("\n");
                    exit(1);
                } else {
                    printf("((ARP)) "); 
                    print_ipv4_addr(ipv4_dstaddr); 
                    printf(" "); 
                    print_hwaddr(eth->h_dest);
                    printf("\n");
                    memcpy(&((struct ethhdr*)sendbuf)->h_dest, (char*)&eth->h_dest, ETH_ALEN);
                }
            }
            if( (wrote_bytes = sendto(sockfd, sendbuf, read_bytes + sizeof(struct ethhdr), 0, (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr))) < 0 ) {
                perror("sendto()");
                close(sockfd);
                exit(1);
            }
        }
    }

    return 0;
}