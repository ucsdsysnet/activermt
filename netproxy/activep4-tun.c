#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <malloc.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <linux/if_tun.h>

#define DEBUG       1

#define TRUE        1
#define BUFSIZE     16384
#define MAXCONN     65536
#define MAXARP      65536
#define ARPMASK     0x0000FFFF
#define IPADDRSIZE  16
#define TUNOFFSET   4
#define MAXARGS     10
#define MAXPROGLEN  50
#define MAXFILESIZE 1024
#define ACTIVEP4SIG 0x12345678
#define CRCPOLY_DNP 0x3D65
#define ETHTYPE_AP4 0x83B2

typedef struct {
    uint32_t    SIG;
    uint16_t    flags;
    uint16_t    fid;
    uint16_t    seq;
    uint16_t    acc;
    uint16_t    acc2;
    uint16_t    data;
    uint16_t    data2;
    uint16_t    res;
} activep4_ih;

typedef struct {
    uint8_t     flags;
    uint8_t     opcode;
    uint16_t    arg;
} activep4_instr;

typedef struct {
    char        argname[20];
    uint8_t     valid;
    int         idx;
} activep4_arg;

typedef struct {
    char        argname[20];
    uint16_t    argval;
} activep4_argval;

typedef struct {
    activep4_instr  ap4_prog[MAXPROGLEN];
    activep4_arg    ap4_argmap[MAXARGS];
    int             ap4_len;
    int             num_args;
    uint16_t        fid;
} activep4_t;

typedef struct {
    int             iface_index;
    unsigned char   hwaddr[ETH_ALEN];
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

// APPLICATIONS

typedef struct {
    uint8_t         active;
    uint8_t         awterm;
    uint16_t        cookie;
    inet_5tuple_t   conn;
} cheetah_lb_t;

int allocate_tun(char* dev, int flags) {
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
    printf("hwaddr: %.2x:%.2x:%.2x:%.2x:%.2x:%.2x\n", hwaddr[0], hwaddr[1], hwaddr[2], hwaddr[3], hwaddr[4], hwaddr[5]);
}

void get_iface(devinfo_t* info, char* dev, int fd) {
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
    info->iface_index = ifr.ifr_ifindex;
    if(ioctl(fd, SIOCGIFHWADDR, &ifr) < 0) {
        perror("ioctl");
        exit(1);
    }
    memcpy(info->hwaddr, (unsigned char*)ifr.ifr_hwaddr.sa_data, ETH_ALEN);
    #ifdef DEBUG
    printf("Device %s has iface index %d\n", dev, info->iface_index);
    #endif
    printf("Device %s has hwaddr %.2x:%.2x:%.2x:%.2x:%.2x:%.2x\n", dev, info->hwaddr[0], info->hwaddr[1], info->hwaddr[2], info->hwaddr[3], info->hwaddr[4], info->hwaddr[5]);
}

int get_arp_cache(arp_entry_t* arp_cache) {
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

static inline int insert_active_program(char* buf, activep4_t* ap4, activep4_argval* args, int numargs) {
    int offset = 0, i;
    char* bufptr = buf;
    uint16_t fid = ap4->fid;
    activep4_instr* prog = ap4->ap4_prog;
    activep4_arg* argmap = ap4->ap4_argmap;
    activep4_instr* instr;
    int numinstr = ap4->ap4_len;
    activep4_ih* ih = (activep4_ih*) bufptr;
    ih->SIG = htonl(ACTIVEP4SIG);
    ih->fid = htons(fid);
    offset += sizeof(activep4_ih);
    bufptr += offset;
    int j;
    for(i = 0; i < MAXARGS; i++) {
        if(argmap[i].valid == 1) {
            argmap[i].idx = -1;
            for(j = 0; j < numargs; j++) {
                if(strcmp(args[j].argname, argmap[i].argname) == 0)
                    argmap[i].idx = j;
            }
        }
    }
    for(i = 0; i < numinstr; i++) {
        instr = (activep4_instr*) bufptr;
        instr->flags = prog[i].flags;
        instr->opcode = prog[i].opcode;
        instr->arg = (argmap[i].valid == 1) ? htons(args[argmap[i].idx].argval) : 0;
        #ifdef DEBUG
        printf("AP4: %d,%d,%d\n", instr->flags, instr->opcode, instr->arg);
        #endif
        offset += sizeof(activep4_instr);
        bufptr += sizeof(activep4_instr);
    }
    return offset;
}

static inline int read_active_program(activep4_t* ap4, char* prog_file) {
    FILE* fp = fopen(prog_file, "rb");
    activep4_instr* prog = ap4->ap4_prog;
    fseek(fp, 0, SEEK_END);
    int ap4_size = ftell(fp);
    rewind(fp);
    char fbuf[MAXFILESIZE];
    fread(fbuf, ap4_size, 1, fp);
    fclose(fp);
    int i = 0, j = 0;
    uint16_t arg;
    while(i < MAXPROGLEN && j < ap4_size) {
        arg = fbuf[j + 2] << 8 + fbuf[j + 3];
        prog[i].flags = fbuf[j];
        prog[i].opcode = fbuf[j + 1];
        prog[i].arg = htons(arg);
        i++;
        j += 4;
    }
    ap4->ap4_len = i;
    return i;
}

static inline int read_active_args(activep4_t* ap4, char* arg_file) {
    FILE* fp = fopen(arg_file, "r");
    activep4_arg* argmap = ap4->ap4_argmap;
    char buf[50];
    const char* tok;
    char argname[50];
    int i, argidx;
    for(i = 0; i < MAXARGS; i++) argmap[i].valid = 0;
    while( fgets(buf, 50, fp) > 0 ) {
        for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, "\n"), i++) {
            if(i == 0) strcpy(argname, tok);
            else argidx = atoi(tok);
        }
        strcpy(argmap[argidx].argname, argname);
        argmap[argidx].valid = 1;
        #ifdef DEBUG
        printf("Active argument %s at index %d\n", argmap[argidx].argname, argidx);
        #endif
    }
    fclose(fp);
    ap4->num_args = argidx;
    return argidx;
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

static inline int active_filter_tcp(struct iphdr* iph, struct tcphdr* tcph, char* buf, activep4_t* ap4, cheetah_lb_t* app) {
    int numargs = 2, offset = 0;
    uint16_t vip_addr, conn_id;
    inet_5tuple_t conn = {
        iph->saddr,
        iph->daddr,
        iph->protocol,
        tcph->source,
        tcph->dest
    };
    activep4_ih* ap4ih;
    conn_id = cksum_5tuple(&conn);
    if(tcph->syn == 1 && tcph->ack == 0) {
        // SYN packet
        #ifdef DEBUG
        printf("TCP connection initiation.\n");
        #endif
        vip_addr = (uint16_t) (ntohl(iph->daddr) & 0x0000FFFF);
        // TODO apply mask and offset
        activep4_argval args[] = {
            {"BUCKET_SIZE", 4},
            {"VIP_ADDR", vip_addr}
        };
        offset = insert_active_program(buf, ap4, args, numargs);
        app[conn_id].active = 1;
        app[conn_id].cookie = 0;
        app[conn_id].awterm = 0;
        memcpy(&app[conn_id].conn, &conn, sizeof(inet_5tuple_t));
    } else {
        // other TCP segments
        ap4ih = (activep4_ih*)buf;
        ap4ih->SIG = htonl(ACTIVEP4SIG);
        ap4ih->fid = htons(ap4->fid);
        ap4ih->flags = htons(0x0100);
        ap4ih->acc = htons(app[conn_id].cookie);
        offset = sizeof(activep4_ih);
    }
    if(tcph->fin == 1) {
        // FIN packet
        app[conn_id].awterm = 1;
    }
    return offset;
}

static inline void active_update(struct iphdr* iph, struct tcphdr* tcph, activep4_ih* ap4ih, cheetah_lb_t* app) {
    inet_5tuple_t conn = {
        iph->saddr,
        iph->daddr,
        iph->protocol,
        tcph->source,
        tcph->dest
    };
    uint16_t conn_id = cksum_5tuple(&conn);
    if(tcph->syn == 1) {
        // SYN packet (either way)
        app[conn_id].active = 1;
        app[conn_id].cookie = ntohs(ap4ih->acc);
        memcpy(&app[conn_id].conn, &conn, sizeof(inet_5tuple_t));
        #ifdef DEBUG
        printf("SYN: setting (for connection %u) cookie to %u\n", conn_id, app[conn_id].cookie);
        #endif
    } else if(tcph->ack == 1 && app[conn_id].awterm == 1) {
        #ifdef DEBUG
        printf("FIN: terminating connection %u\n", conn_id);
        #endif
        app[conn_id].active = 0;
        app[conn_id].cookie = 0;
        app[conn_id].awterm = 0;
        memset(&app[conn_id].conn, 0, sizeof(inet_5tuple_t));
    }
}

static inline int get_active_eof(char* buf) {
    int eof = 0;
    activep4_instr* instr = (activep4_instr*) buf;
    while(instr->opcode != 0) {
        eof = eof + sizeof(activep4_instr);
        instr++;
    }
    eof = eof + sizeof(activep4_instr);
    return eof;
}

static inline int is_activep4(char* buf) {
    uint32_t* signature = (uint32_t*) buf;
    return (ntohl(*signature) == ACTIVEP4SIG);
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("usage: %s <remote_addr> <active_program> [active_args] [fid=1]\n", argv[0]);
        exit(1);
    }

    struct sockaddr_in sin, tin;

    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr(argv[1]);

    tin.sin_family = AF_INET;

    activep4_t      ap4;
    cheetah_lb_t    app[MAXCONN];
    
    int ap4_len = read_active_program(&ap4, argv[2]);
    int num_args = (argc > 3) ? read_active_args(&ap4, argv[3]) : 0;

    ap4.fid = (argc > 4) ? atoi(argv[4]) : 1;
    
    char dev[IFNAMSIZ];

    strcpy(dev, "tun0");
    
    //int tunfd = allocate_tun(dev, IFF_TUN | IFF_NO_PI);
    int tunfd = allocate_tun(dev, IFF_TUN);

    if(tunfd < 0) {
        perror("Unable to get TUN interface.");
        exit(1);
    }

    int conn = socket(PF_INET, SOCK_RAW, IPPROTO_RAW);
    int sockfd;
    if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("raw socket");
        exit(1);
    }

    devinfo_t dev_info;

    get_iface(&dev_info, "eth1", sockfd);

    arp_entry_t arp_cache[MAXARP];

    get_arp_cache(arp_cache);

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
    uint16_t ap4_flags;

    struct ethhdr*  eth;
    struct iphdr*   iph;
    struct tcphdr*  tcph;

    activep4_ih* ap4ih;

    char ipaddr[IPADDRSIZE];

    uint16_t pkt_size;
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
            perror("select()");
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
                        if(((ap4_flags & 0x0100) >> 8) == 0) offset = get_active_eof(recvbuf + sizeof(struct ethhdr) + sizeof(activep4_ih));
                        offset += sizeof(activep4_ih);
                        iph = (struct iphdr*) (recvbuf + sizeof(struct ethhdr) + offset);
                        #ifdef DEBUG
                        inet_ntop(AF_INET, &iph->daddr, ipaddr, IPADDRSIZE);
                        printf("== RELAY: %d bytes to %s\n", ntohs(iph->tot_len), ipaddr);
                        #endif
                        tin.sin_addr.s_addr = (in_addr_t)iph->daddr;
                        memset(sendbuf, 0, BUFSIZE);
                        memcpy(sendbuf, recvbuf + sizeof(struct ethhdr) + offset, ntohs(iph->tot_len));
                        if( sendto(conn, sendbuf, ntohs(iph->tot_len), 0, (struct sockaddr*)&tin, sizeof(tin)) < 0 )
                        perror("tunnel()");
                        if(iph->protocol == IPPROTO_TCP) {
                            tcph = (struct tcphdr*) (recvbuf + sizeof(struct ethhdr) + offset + sizeof(struct iphdr));
                            active_update(iph, tcph, ap4ih, app);
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
                    ap4_offset = active_filter_tcp(iph, tcph, pptr, &ap4, app);
                    pptr += ap4_offset;
                }
                memcpy(pptr, recvbuf + TUNOFFSET, ntohs(iph->tot_len));
                if( sendto(sockfd, sendbuf, sizeof(struct ethhdr) + ntohs(iph->tot_len) + ap4_offset, 0, (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr)) < 0 )
                    perror("sendto()");
                #ifdef DEBUG
                inet_ntop(AF_INET, &iph->daddr, ipaddr, IPADDRSIZE);
                printf(">> FRAME: %d bytes read from packet to %s with IP length %d\n", read_bytes, ipaddr, ntohs(iph->tot_len));
                #endif
            }
        }
    }

    return 0;
}