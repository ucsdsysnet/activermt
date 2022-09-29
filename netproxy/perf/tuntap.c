#define _GNU_SOURCE
//#define DEBUG       1
#define TRUE            1
#define TUNOFFSET       0
#define BUFSIZE         4096
#define IPADDRSIZE      16
#define ETH_P_AP4       0x83B2
#define AP4_FID         1
#define MTU             1500

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
#include <pthread.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/queue.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <linux/if_tun.h>

#include "../../headers/activep4.h"
#include "../../headers/stats.h"
#include "../../headers/payload_parser_resp.h"

typedef struct {
    char*           iface_name;
    int             iface_index;
    unsigned char   hwaddr[ETH_ALEN];
    uint32_t        ipv4addr;
} devinfo_t;

typedef struct {
    redis_command_t     rcmd;
} redis_context_t;

typedef struct {
    struct ethhdr*      eth;
    struct iphdr*       iph;
    struct tcphdr*      tcph;
    struct udphdr*      udph;
    activep4_ih*        ap4ih;
    activep4_data_t*    ap4args;
    char*               payload;
} net_headers_t;

typedef struct {
    int                 tunfd;
    int                 sockfd;
    devinfo_t           dev_info;
    devinfo_t           tun_info;
    struct sockaddr_ll  eth_dst_addr;
    int                 maxfd;
    void*               app_context;
} rx_tx_config_t;

typedef struct {
    pnemonic_opcode_t   instr_set;
    activep4_t          ap4prog;
    int                 prog_offset;
    char                sendbuf[BUFSIZE];
    char*               recvbuf;
    rx_tx_config_t*     devcfg;
    void                (*tx_filter)(net_headers_t*, activep4_data_t*, void*);   
} tx_config_t;

typedef struct {
    int                 local;
    struct sockaddr_in  loc_in;
    char                sendbuf[BUFSIZE];
    char                recvbuf[BUFSIZE];
    rx_tx_config_t*     devcfg;
    void                (*rx_filter)(net_headers_t*, void*);
} rx_config_t;

stats_t stats;

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

static inline int activep4_get_ipv4_offset(char* buf) {
    struct ethhdr* eth = (struct ethhdr*) buf;
    int offset = sizeof(struct ethhdr);
    if(ntohs(eth->h_proto) == ETH_P_AP4) {
        offset += sizeof(activep4_ih);
        if(ntohs(((activep4_ih*)&eth[1])->flags) & AP4FLAGMASK_OPT_ARGS) offset += sizeof(activep4_data_t);
        offset += get_active_eof(buf + offset);
    }
    return offset;
}

static inline int extract_network_headers(char* buf, net_headers_t* hdrs) {
    buf += TUNOFFSET;
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
    } else if(iph->protocol == IPPROTO_UDP) {
        udph = (struct udphdr*)(buf + offset);
        offset += sizeof(struct udphdr);
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

static void interrupt_handler(int sig) {
    write_stats(&stats, "tuntap_stats.csv");
    exit(1);
}

static inline int serialize_redis_data(char* buf, uint32_t response, int len) {
    int buflen = 10;
    response = ntohl(response);
    sprintf(buf, "$4\r\n%c%c%c%c\r\n", (char)(response >> 24), (char)(response >> 16), (char)(response >> 8), (char)response );
    buf[buflen] = '\0';
    while(buflen++ < len) buf[buflen] = '\0';
    return buflen;
}

static inline void tx_filter_redis(net_headers_t* hdrs, void* ctxt) {
    // insert key into args based on payload.
    redis_context_t* context = (redis_context_t*) ctxt;
    activep4_data_t* args = hdrs->ap4args;
    /*deserialize_redis_data(payload, len, &context->rcmd);
    if(context->rcmd.cmd_get == 1) {
        uint32_t redis_key = htonl(*((uint32_t*)context->rcmd.key));
        memcpy(&args->data[1], (char*)&redis_key, sizeof(uint32_t));
    }*/
}

static inline void rx_filter_redis(net_headers_t* hdrs, void* ctxt) {
    // match response value to request key.
    redis_context_t* context = (redis_context_t*) ctxt;
    /*deserialize_redis_data(hdrs->payload, len, &context->rcmd);
    if(context->rcmd.cmd_get == 1 && context->rcmd.val_len > 0) {
        // TODO handle KV response.
        memset(context, 0, sizeof(redis_context_t));
    }*/
}

void* rx_loop(void* argp) {

    rx_config_t* rx_cfg = (rx_config_t*) argp;

    fd_set rd_set;
    int maxfd = rx_cfg->devcfg->sockfd, ret, offset;
    int read_bytes, wrote_bytes;

    char* recvbuf = rx_cfg->recvbuf;

    /*struct ethhdr*  eth;
    struct iphdr*   iph;
    activep4_ih*    ap4ih;*/
    net_headers_t hdrs;

    printf("Starting RX loop ... \n");

    while(TRUE) {
        FD_ZERO(&rd_set);
        FD_SET(rx_cfg->devcfg->sockfd, &rd_set);

        ret = select(maxfd + 1, &rd_set, NULL, NULL, NULL);
        if(ret < 0 && errno == EINTR) continue;
        if(ret < 0) {
            perror("select");
            exit(1);
        }

        read_bytes = 0;
        wrote_bytes = 0;

        if(FD_ISSET(rx_cfg->devcfg->sockfd, &rd_set)) {
            if( (read_bytes = read(rx_cfg->devcfg->sockfd, recvbuf, BUFSIZE)) < 0 ) {
                perror("read()");
                close(rx_cfg->devcfg->sockfd);
                exit(1);
            }
            if(read_bytes > (sizeof(struct ethhdr) + sizeof(struct iphdr))) {
                memset(&hdrs, 0, sizeof(net_headers_t));
                if(extract_network_headers(recvbuf, &hdrs) < 0) {
                    printf("Invalid packet received.\n");
                    continue;
                }
                if(hwaddr_equals(hdrs.eth->h_dest, rx_cfg->devcfg->dev_info.hwaddr)) {
                    #ifdef DEBUG
                    printf("[ETH] [%d Bytes] ", read_bytes);
                    #endif
                    if(hdrs.ap4ih != NULL) {
                        rx_cfg->rx_filter(&hdrs, rx_cfg->devcfg->app_context);
                        if( (wrote_bytes = sendto(rx_cfg->local, (char*)hdrs.iph, ntohs(hdrs.iph->tot_len), 0, (struct sockaddr*)&rx_cfg->loc_in, sizeof(struct sockaddr_in))) < 0 )
                            perror("sendto");
                        #ifdef DEBUG
                        printf("[AP4] (forwarded %d bytes ... ) ", wrote_bytes);
                        #endif
                        /*if( (wrote_bytes = write(tunfd, (char*)iph, read_bytes)) < 0 ) {
                            perror("write()");
                            close(sockfd);
                            exit(1);
                        }*/
                    }
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

    tx_config_t* tx_cfg = (tx_config_t*) argp;

    fd_set rd_set;
    int maxfd = tx_cfg->devcfg->tunfd, ret;
    int read_bytes, wrote_bytes;
    int eth_dst_resolved = 0;

    char* recvbuf = tx_cfg->recvbuf;
    char* sendbuf = tx_cfg->sendbuf;

    uint32_t ipv4_dstaddr;

    struct ethhdr*  eth = (struct ethhdr*) sendbuf;

    net_headers_t hdrs;

    printf("Starting TX loop ... \n");

    while(TRUE) {
        FD_ZERO(&rd_set);
        FD_SET(tx_cfg->devcfg->tunfd, &rd_set);

        ret = select(maxfd + 1, &rd_set, NULL, NULL, NULL);
        if(ret < 0 && errno == EINTR) continue;
        if(ret < 0) {
            perror("select");
            exit(1);
        }

        read_bytes = 0;
        wrote_bytes = 0;

        if(FD_ISSET(tx_cfg->devcfg->tunfd, &rd_set)) {
            if( (read_bytes = read(tx_cfg->devcfg->tunfd, recvbuf, BUFSIZE)) < 0 ) {
                perror("read()");
                close(tx_cfg->devcfg->tunfd);
                exit(1);
            }
            #ifdef DEBUG
            if(read_bytes > TUNOFFSET) {
                printf("[TUN] [%d Bytes] ", read_bytes);
                print_pktinfo(sendbuf);
            }
            #endif
            if(extract_network_headers(sendbuf, &hdrs) < 0 ) {
                printf("Error: packet invalid!\n");
                continue;
            }
            if(eth_dst_resolved == 0) {
                // Assuming (/24) mapping: x.x.x.y -> z.z.z.y
                ipv4_dstaddr = (hdrs.iph->daddr & 0xFF000000) | (tx_cfg->devcfg->dev_info.ipv4addr & 0x00FFFFFF);
                if( (eth_dst_resolved = arp_resolve(ipv4_dstaddr, tx_cfg->devcfg->dev_info.iface_name, eth->h_dest)) == 0 ) {
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
            tx_filter_redis(&hdrs, tx_cfg->devcfg->app_context);
            if( (wrote_bytes = sendto(tx_cfg->devcfg->sockfd, sendbuf, read_bytes + sizeof(struct ethhdr) + tx_cfg->prog_offset, 0, (struct sockaddr*)&tx_cfg->devcfg->eth_dst_addr, sizeof(struct sockaddr_ll))) < 0 ) {
                perror("sendto()");
                close(tx_cfg->devcfg->sockfd);
                exit(1);
            }
            pthread_mutex_lock(&lock);
            stats.count++;
            pthread_mutex_unlock(&lock);
        }
    }
}

int main(int argc, char** argv) {

    if(argc < 4) {
        printf("Usage: %s <tun_iface> <eth_iface> <path_to_instr_set>\n", argv[0]);
        exit(1);
    }

    signal(SIGINT, interrupt_handler);

    char* tun_iface = argv[1];
    char* eth_iface = argv[2];
    char* instr_set_path = argv[3];

    rx_tx_config_t  cfg;
    tx_config_t     tx_cfg;
    rx_config_t     rx_cfg;

    memset(&cfg, 0 , sizeof(rx_tx_config_t));
    memset(&tx_cfg, 0, sizeof(tx_config_t));
    memset(&rx_cfg, 0, sizeof(rx_config_t));

    tx_cfg.devcfg = &cfg;
    rx_cfg.devcfg = &cfg;

    struct sockaddr_in tin;

    tin.sin_family = AF_INET;

    cfg.tunfd = allocate_tun(tun_iface, IFF_TUN | IFF_NO_PI);

    if(cfg.tunfd < 0) {
        perror("Unable to get TUN interface");
        exit(1);
    }

    if((cfg.sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }

    cfg.dev_info.iface_name = eth_iface;
    get_iface(&cfg.dev_info, eth_iface, cfg.sockfd);

    int sock_tun;

    if((sock_tun = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }

    cfg.tun_info.iface_name = tun_iface;
    get_iface(&cfg.tun_info, tun_iface, sock_tun);
    close(sock_tun);

    struct sockaddr_ll addr = {0};
    addr.sll_family = AF_PACKET;
    addr.sll_ifindex = cfg.dev_info.iface_index;
    addr.sll_protocol = htons(ETH_P_ALL);

    if(bind(cfg.sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("bind");
        exit(1);
    }

    memset(&cfg.eth_dst_addr, 0, sizeof(struct sockaddr_ll));
    cfg.eth_dst_addr.sll_family = AF_PACKET;
    cfg.eth_dst_addr.sll_ifindex = cfg.dev_info.iface_index;
    cfg.eth_dst_addr.sll_protocol = htons(ETH_P_AP4);
    cfg.eth_dst_addr.sll_halen = ETH_ALEN;

    tx_cfg.recvbuf = tx_cfg.sendbuf + sizeof(struct ethhdr);

    memset(tx_cfg.sendbuf, 0, BUFSIZE);
    memset(rx_cfg.sendbuf, 0, BUFSIZE);
    memset(rx_cfg.recvbuf, 0, BUFSIZE);

    // Construct NOP active program.

    read_opcode_action_map(instr_set_path, &tx_cfg.instr_set);
    construct_nop_program(&tx_cfg.ap4prog, &tx_cfg.instr_set, 10);
    
    activep4_ih* ap4ih = (activep4_ih*) tx_cfg.recvbuf;
    ap4ih->SIG = htonl(ACTIVEP4SIG);
    ap4ih->fid = htons(AP4_FID);
    ap4ih->flags = htons(AP4FLAGMASK_OPT_ARGS);

    activep4_data_t* ap4args = (activep4_data_t*) (tx_cfg.recvbuf + sizeof(activep4_ih));

    activep4_instr* ap4instr = (activep4_instr*) (tx_cfg.recvbuf + sizeof(activep4_ih) + sizeof(activep4_data_t));
    memcpy(ap4instr, (char*)&tx_cfg.ap4prog.ap4_prog, tx_cfg.ap4prog.ap4_len * sizeof(activep4_instr));

    // TODO: program execution on the switch will reduce length.
    int active_program_offset = sizeof(activep4_ih) + sizeof(activep4_data_t) + tx_cfg.ap4prog.ap4_len * sizeof(activep4_instr);
    tx_cfg.recvbuf += active_program_offset;
    tx_cfg.prog_offset = active_program_offset;

    struct ethhdr*  eth = (struct ethhdr*) tx_cfg.sendbuf;
    struct iphdr*   iph;

    memcpy(&eth->h_source, &cfg.dev_info.hwaddr, ETH_ALEN);
    eth->h_proto = htons(ETH_P_AP4);

    // TODO: local socket to forward packet stripped of active program.
    rx_cfg.local = socket(PF_INET, SOCK_RAW, IPPROTO_RAW);
    rx_cfg.loc_in.sin_family = AF_INET;
    rx_cfg.loc_in.sin_addr.s_addr = (in_addr_t)cfg.tun_info.ipv4addr;

    memset(&stats, 0, sizeof(stats_t));

    cpu_set_t cpuset_timer, cpuset_rx, cpuset_tx;

    pthread_t timer_thread;
    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    CPU_ZERO(&cpuset_timer);
    CPU_SET(40, &cpuset_timer);
    if(pthread_setaffinity_np(timer_thread, sizeof(cpu_set_t), &cpuset_timer) != 0) {
        perror("pthread_setaffinity()");
    }

    pthread_t rx_thread;
    if( pthread_create(&rx_thread, NULL, rx_loop, (void*)&rx_cfg) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    CPU_ZERO(&cpuset_rx);
    CPU_SET(42, &cpuset_rx);
    if(pthread_setaffinity_np(rx_thread, sizeof(cpu_set_t), &cpuset_rx) != 0) {
        perror("pthread_setaffinity()");
    }

    pthread_t tx_thread;
    if( pthread_create(&tx_thread, NULL, tx_loop, (void*)&tx_cfg) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    CPU_ZERO(&cpuset_tx);
    CPU_SET(44, &cpuset_tx);
    if(pthread_setaffinity_np(tx_thread, sizeof(cpu_set_t), &cpuset_tx) != 0) {
        perror("pthread_setaffinity()");
    }

    pthread_join(timer_thread, NULL);
    pthread_join(rx_thread, NULL);
    pthread_join(tx_thread, NULL);

    return 0;
}