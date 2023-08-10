#define NUM_STAGES      20
#define IPADDRSIZE      16
#define BUFSIZE         16384
#define ETHTYPE_AP4     0x83B2
#define ETHTYPE_IP      0x0800
#define MAX_DATA        65536

#define DEBUG

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>
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

#include "../../activep4.h"

#define AP4_TESTFLAG(x, y)  (x & y) > 0
#define TIMESTAMP(x)        if( clock_gettime(CLOCK_MONOTONIC, &x) < 0 ) { perror("clock_gettime"); exit(1); }

typedef struct {
    activep4_malloc_block_t mem_range[NUM_STAGES];
} __attribute__((packed)) activep4_malloc_res_t;

typedef struct {
    int             iface_index;
    unsigned char   hwaddr[ETH_ALEN];
    uint32_t        ipv4addr;
} devinfo_t;

typedef struct {
    uint16_t    data[MAX_DATA];
    uint8_t     valid[MAX_DATA];
    int         mem_start;
    int         mem_end;
} memory_stage_t;

typedef struct {
    memory_stage_t  sync_data[NUM_STAGES];
    uint8_t         valid_stages[NUM_STAGES];
    uint16_t        fid;
    uint64_t        sync_duration;
    struct timespec sync_time;
} memory_t;

typedef struct {
    activep4_ih             ap4ih;
    activep4_data_t         ap4data;
    activep4_instr          ap4code[MAXPROGLEN];
    int                     codelen;
    activep4_malloc_req_t   ap4malloc;
    activep4_malloc_res_t   ap4alloc;
} active_program_t;

/* ********************************************************************** */

typedef struct {
    int         stage_id;
    uint16_t    index;
} active_memsync_state_t;

typedef struct {
    uint8_t                 allocation_initiated;
    uint8_t                 allocation_complete;
    uint8_t                 remap_initiated;
    uint8_t                 allocreq_in_progress;
    uint8_t                 allocfetch_in_progress;
    uint8_t                 memsync_in_progress;
    active_memsync_state_t  mstate;
} active_control_t;

/* ********************************************************************** */

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

static inline int hwaddr_equals(unsigned char* a, unsigned char* b) {
    return ( a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && a[5] == b[5] );
}

static inline void prettify_duration(unsigned long ts, char* buf) {
    if(ts < 1E3) sprintf(buf, "%lu ns", ts);
    else if(ts < 1E6) sprintf(buf, "%lf us", ts / 1E3);
    else if(ts < 1E9) sprintf(buf, "%lf ms", ts / 1E6);
    else sprintf(buf, "%lf s", ts / 1E9);
}

/* ********************************************************************** */

void construct_malloc_request_pkt(active_program_t* txprog, int fid, int num_accesses, int* access_idx, int* demand, int proglen, int iglim) {

    uint16_t flags = AP4FLAGMASK_FLAG_REQALLOC;

    memset((char*)txprog, 0, sizeof(active_program_t));

    txprog->ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog->ap4ih.fid = htons(fid);
    txprog->ap4ih.flags = htons(flags);

    txprog->codelen = 0;

    int i;

    txprog->ap4malloc.proglen = htons(proglen);
    txprog->ap4malloc.iglim = iglim;
    for(i = 0; i < num_accesses; i++) {
        txprog->ap4malloc.mem[i] = access_idx[i];
        txprog->ap4malloc.dem[i] = demand[i];
    }
}

void construct_malloc_fetch_pkt(active_program_t* txprog, int fid) {

    uint16_t flags = AP4FLAGMASK_FLAG_GETALLOC;

    memset((char*)txprog, 0, sizeof(active_program_t));

    txprog->ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog->ap4ih.fid = htons(fid);
    txprog->ap4ih.flags = htons(flags);

    txprog->codelen = 0;
}

void construct_memsync_pkt(active_program_t* txprog, pnemonic_opcode_t* instr_set, activep4_t* cache, uint16_t index, int stageId, int fid) {

    uint16_t flags = AP4FLAGMASK_OPT_ARGS;

    activep4_t* program;

    memset((char*)txprog, 0, sizeof(active_program_t));

    program = construct_memsync_program(fid, stageId, instr_set, cache);

    txprog->ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog->ap4ih.fid = htons(fid);
    txprog->ap4ih.flags = htons(flags);

    txprog->ap4data.data[0] = htonl(index);
    txprog->ap4data.data[1] = 0;
    txprog->ap4data.data[2] = htonl(stageId);
    txprog->ap4data.data[3] = 0;

    memcpy((char*)&txprog->ap4code, (char*)&program->ap4_prog, sizeof(activep4_instr) * MAXPROGLEN);
    txprog->codelen = program->ap4_len;
}

/* ********************************************************************** */

void memsync_init(active_memsync_state_t* mstate, memory_t* activemem) {
    int i, j, stageId = -1;
    for(i = 0; i < NUM_STAGES; i++) {
        stageId = (stageId >= 0) ? stageId : (activemem->valid_stages[i] == 1) ? i : stageId;
        if(activemem->valid_stages[i] == 0) continue;
        for(j = activemem->sync_data[i].mem_start; j <= activemem->sync_data[i].mem_end; j++) {
            activemem->sync_data[i].valid[j] = 0;
        }
    }
    mstate->stage_id = stageId;
    mstate->index = activemem->sync_data[mstate->stage_id].mem_start;
}

int memsync_next(active_memsync_state_t* mstate, memory_t* activemem) {
    do {
        mstate->index++;
        if(mstate->index > activemem->sync_data[mstate->stage_id].mem_end) {
            do {
                mstate->stage_id++;
                if(mstate->stage_id >= NUM_STAGES) return 0;
            } while(activemem->valid_stages[mstate->stage_id] == 0);
            mstate->index = activemem->sync_data[mstate->stage_id].mem_start;
        }
    } while(activemem->sync_data[mstate->stage_id].valid[mstate->index] == 1);
    return 1;
}

int memsync_check(active_memsync_state_t* mstate, memory_t* activemem) {
    int i, j, synced = 1, stageId = -1;
    for(i = 0; i < NUM_STAGES; i++) {
        stageId = (stageId >= 0) ? stageId : (activemem->valid_stages[i] == 1) ? i : stageId;
        if(activemem->valid_stages[i] == 0) continue;
        for(j = activemem->sync_data[i].mem_start; j <= activemem->sync_data[i].mem_end; j++) {
            if(activemem->sync_data[i].valid[j] == 0) synced = 0;
        }
    }
    if(synced == 0) {
        mstate->stage_id = stageId;
        mstate->index = activemem->sync_data[mstate->stage_id].mem_start;
    }
    return synced;
}

/*void memsync(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache) {
    if(syncInit == 1) return;
    syncInit = 1;
    int i, j, synced, sync_batches, num_pkts, remaining;
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns = 0;
    //#ifdef DEBUG
    printf("Initiating memory sync for FID %d ... \n", coredump.fid);
    //#endif
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
            coredump.sync_data[i].valid[j] = 0;
        }
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        synced = 0;
        sync_batches = 0;
        while(synced == 0 && sync_batches < MAX_SYNC_R) {
            synced = 1;
            remaining = 0;
            for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
                if(coredump.sync_data[i].valid[j] == 0) {
                    synced = 0;
                    remaining++;
                    send_memsync_pkt(instr_set, queue, cache, j, i, coredump.fid);
                }
            }
            //#ifdef DEBUG
            printf("%d packets remaining ... \n", remaining);
            if(synced == 1) {
                num_pkts = coredump.sync_data[i].mem_end - coredump.sync_data[i].mem_start + 1;
                printf("[FID %d] Memory sync (with %d packets) complete for stage %d in %d batches\n", coredump.fid, num_pkts, i, sync_batches);
            }
            //#endif
            sync_batches++;
            //usleep(RETRY_ITVL);
        }
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    coredump.sync_time.tv_sec = ts_now.tv_sec;
    coredump.sync_time.tv_nsec = ts_now.tv_nsec;
    coredump.sync_duration = elapsed_ns;
    //#ifdef DEBUG
    char duration[100];
    prettify_duration(elapsed_ns, duration);
    printf("Memory sync for FID %d completed after %s\n", coredump.fid, duration);
    //#endif
    syncInit = 0;
}*/

/* ********************************************************************** */

static inline void on_allocation_packet(memory_t* activemem, active_program_t* recvap) {
    int i;
    for(i = 0; i < NUM_STAGES; i++) {
        activemem->sync_data[i].mem_start = ntohs(recvap->ap4alloc.mem_range[i].start);
        activemem->sync_data[i].mem_end = ntohs(recvap->ap4alloc.mem_range[i].end);
        if((activemem->sync_data[i].mem_end - activemem->sync_data[i].mem_start) > 0) {
            activemem->valid_stages[i] = 1;
            #ifdef DEBUG
            printf("[S%d: %d-%d] ", i, activemem->sync_data[i].mem_start, activemem->sync_data[i].mem_end);
            #endif
        }
    }
    #ifdef DEBUG
    printf("\n");
    #endif
}

static inline void on_memsync_packet(memory_t* activemem, active_program_t* recvap) {
    uint16_t index, stageId, value;
    index = ntohl(recvap->ap4data.data[0]);
    stageId = ntohl(recvap->ap4data.data[2]);
    value = ntohl(recvap->ap4data.data[1]);
    if(activemem->valid_stages[stageId] > 0 
        && index >= activemem->sync_data[stageId].mem_start 
        && index <= activemem->sync_data[stageId].mem_end
    ) {
        activemem->sync_data[stageId].data[index] = value;
        activemem->sync_data[stageId].valid[index] = 1;
    }
}

static inline void on_active_pkt_recv(
    struct ethhdr* eth, 
    struct iphdr* iph, 
    active_program_t* recvap,
    active_control_t* ctrl,
    memory_t* activemem
) {
    uint16_t fid = ntohs(recvap->ap4ih.fid);
    uint16_t flags = ntohs(recvap->ap4ih.flags);

    if(activemem->fid != fid) return;

    #ifdef DEBUG
    //printf("FLAGS 0x%x\n", flags);
    #endif

    if(AP4_TESTFLAG(flags, AP4FLAGMASK_FLAG_REQALLOC)) {
        ctrl->allocreq_in_progress = 0;
        ctrl->allocfetch_in_progress = 1;
    } else if(AP4_TESTFLAG(flags, AP4FLAGMASK_FLAG_ALLOCATED)) {
        // Allocation response packet.
        #ifdef DEBUG
        printf("(ALLOCATION) <FID %d> ", fid);
        #endif
        on_allocation_packet(activemem, recvap);
        ctrl->allocation_complete = 1;
        ctrl->allocfetch_in_progress = 0;
        memsync_init(&ctrl->mstate, activemem);
        ctrl->memsync_in_progress = 1;
    } else if(AP4_TESTFLAG(flags, AP4FLAGMASK_FLAG_REMAPPED)) {
        // Remap packet.
        ctrl->remap_initiated = 1;
        // printf("Remap packet 0x%x\n", ntohs(ap4ih->flags));
    } else if(AP4_TESTFLAG(flags, AP4FLAGMASK_FLAG_EOE)) {
        // Memsync packet.
        on_memsync_packet(activemem, recvap);
    }
}

/* ********************************************************************** */

int main(int argc, char** argv) {

    if(argc < 5) {
        printf("usage: %s <eth_iface> <src_ipv4_addr> <dst_ipv4_addr> <instr_set_path> [fid=1]\n", argv[0]);
        exit(1);
    }

    char* eth_iface = argv[1];
    char* ipv4_srcaddr = argv[2];
    char* ipv4_dstaddr = argv[3];
    char* instr_set_path = argv[4];
    uint16_t fid = (argc > 5) ? atoi(argv[5]) : 1;

    int sockfd;

    devinfo_t dev_info;

    struct sockaddr_in sockin;

    struct sockaddr_ll eth_dst_addr = {0};
    struct sockaddr_ll addr = {0};

    unsigned char eth_dstmac[ETH_ALEN];
    memset(&eth_dstmac, 0, ETH_ALEN);

    uint16_t ip_id = (uint16_t)rand();

    pnemonic_opcode_t instr_set;
    read_opcode_action_map(instr_set_path, &instr_set);

    memory_t activemem;
    memset(&activemem, 0, sizeof(memory_t));

    active_control_t ap4ctrl;
    memset(&ap4ctrl, 0, sizeof(active_control_t));

    activep4_t cache[NUM_STAGES];

    active_program_t sendap, recvap;
    memset(&sendap, 0, sizeof(active_program_t));
    memset(&recvap, 0, sizeof(active_program_t));

    // configure sockets.

    sockin.sin_family = AF_INET;
    sockin.sin_port = htons(1234);
    sockin.sin_addr.s_addr = inet_addr(ipv4_dstaddr);

    if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }

    /*struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));*/

    get_iface(&dev_info, eth_iface, sockfd);

    addr.sll_family = AF_PACKET;
    addr.sll_ifindex = dev_info.iface_index;
    addr.sll_protocol = htons(ETH_P_ALL);

    if(bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("bind");
        exit(1);
    }

    eth_dst_addr.sll_family = AF_PACKET;
    eth_dst_addr.sll_ifindex = dev_info.iface_index;
    eth_dst_addr.sll_protocol = htons(ETHTYPE_AP4);
    eth_dst_addr.sll_halen = ETH_ALEN;

    fd_set rd_set;

    struct ethhdr*      eth;
    struct iphdr*       iph;
    activep4_ih*        ap4ih;
    activep4_data_t*    ap4data;
    
    activep4_malloc_res_t* ap4alloc;

    uint16_t ap4_flags;

    int ret, read_bytes, ap4_offset, maxfd = sockfd, ap4len, i, sent;

    char recvbuf[BUFSIZE], sendbuf[BUFSIZE];

    char* pptr;

    struct timeval timeout_select;
    timeout_select.tv_sec = 0;
    timeout_select.tv_usec = 0;

    activemem.fid = fid;

    // TODO: Hardcoded.

    int num_accesses, access_idx[NUM_STAGES], demand[NUM_STAGES], proglen, iglim;

    num_accesses = 3;
    access_idx[0] = 3;
    access_idx[1] = 6;
    access_idx[2] = 9;
    demand[0] = 1;
    demand[1] = 1;
    demand[2] = 1;
    proglen = 12;
    iglim = 8;

    // TODO: Hardcoded.

    ap4ctrl.allocreq_in_progress = 1;

    while(TRUE) {
        
        FD_ZERO(&rd_set);
        FD_SET(sockfd, &rd_set);

        ret = select(maxfd + 1, &rd_set, NULL, NULL, &timeout_select);

        if(ret < 0 && errno == EINTR) continue;

        if(ret < 0) {
            perror("select");
            exit(1);
        }

        // RX

        if(FD_ISSET(sockfd, &rd_set)) {
            read_bytes = read(sockfd, recvbuf, sizeof(recvbuf));
            eth = (struct ethhdr*)recvbuf;
            // printf("<< FRAME: %d bytes from protocol 0x%hx\n", read_bytes, ntohs(eth->h_proto));
            // print_hwaddr(eth->h_dest);
            if(!hwaddr_equals(eth->h_dest, eth_dstmac)) {
                if(ntohs(eth->h_proto) == ETHTYPE_AP4) {
                    pptr = recvbuf + sizeof(struct ethhdr);
                    ap4ih = NULL;
                    if(is_activep4(pptr)) {
                        ap4ih = (activep4_ih*) pptr;
                        ap4_flags = ntohs(ap4ih->flags);
                        pptr += sizeof(activep4_ih);
                        if((ap4_flags & AP4FLAGMASK_FLAG_ALLOCATED) != 0) {
                            ap4alloc = (activep4_malloc_res_t*) pptr;
                            pptr += sizeof(activep4_malloc_res_t);
                        } else ap4alloc = NULL;
                        if((ap4_flags & AP4FLAGMASK_OPT_ARGS) != 0) {
                            ap4data = (activep4_data_t*) pptr;
                            pptr += sizeof(activep4_data_t);
                        } else ap4data = NULL;
                        if((ap4_flags & AP4FLAGMASK_FLAG_EOE) == 0) {
                            ap4_offset = get_active_eof(pptr);
                            pptr += ap4_offset;
                        }
                        iph = (struct iphdr*) pptr;
                        pptr += sizeof(struct iphdr);
                        memset(&recvap, 0, sizeof(active_program_t));
                        memcpy(&recvap.ap4ih, (char*)ap4ih, sizeof(activep4_ih));
                        if(ap4data != NULL) memcpy(&recvap.ap4data, (char*)ap4data, sizeof(activep4_data_t));
                        if(ap4alloc != NULL) memcpy(&recvap.ap4alloc, (char*)ap4alloc, sizeof(activep4_malloc_res_t));
                        on_active_pkt_recv(eth, iph, &recvap, &ap4ctrl, &activemem);
                    }
                }
            }
        }

        // TX

        if(ap4ctrl.allocreq_in_progress == 1) {
            // Alloc: request.
            construct_malloc_request_pkt(&sendap, fid, num_accesses, access_idx, demand, proglen, iglim);
        } else if(ap4ctrl.allocfetch_in_progress == 1) {
            // Alloc: fetch.
            construct_malloc_fetch_pkt(&sendap, fid);
        } else if(ap4ctrl.memsync_in_progress == 1) {
            // Memsync.
            printf("MEMSYNC %d,%d\n", ap4ctrl.mstate.index, ap4ctrl.mstate.stage_id);
            construct_memsync_pkt(&sendap, &instr_set, cache, ap4ctrl.mstate.index, ap4ctrl.mstate.stage_id, fid);
            if(memsync_next(&ap4ctrl.mstate, &activemem) == 0) {
                printf("Memsync complete.\n");
                ap4ctrl.memsync_in_progress = 0;
                /*if(memsync_check(&ap4ctrl.mstate, &activemem) == 1) {
                    ap4ctrl.memsync_in_progress = 0;
                    printf("Memsync complete.\n");
                }*/
            }
        } else {
            // App.
            printf("Nothing to do!\n");
            exit(0);
        }

        memset(sendbuf, 0, BUFSIZE);
        pptr = sendbuf;

        eth = (struct ethhdr*)pptr;

        memcpy(&eth->h_source, &dev_info.hwaddr, ETH_ALEN);
        memcpy(&eth->h_dest, eth_dstmac, ETH_ALEN);
        eth->h_proto = htons(ETHTYPE_AP4);

        memcpy(eth_dst_addr.sll_addr, eth_dstmac, ETH_ALEN);

        pptr += sizeof(struct ethhdr);

        ap4len = sizeof(activep4_ih);

        memcpy(pptr, (char*)&sendap.ap4ih, sizeof(activep4_ih));
        
        pptr += sizeof(activep4_ih);

        ap4_flags = ntohs(sendap.ap4ih.flags);

        if(AP4_TESTFLAG(ap4_flags, AP4FLAGMASK_FLAG_REQALLOC)) {
            memcpy(pptr, (char*)&sendap.ap4malloc, sizeof(activep4_malloc_req_t));
            pptr += sizeof(activep4_malloc_req_t);
            ap4len += sizeof(activep4_malloc_req_t);
        }

        if(AP4_TESTFLAG(ap4_flags, AP4FLAGMASK_OPT_ARGS)) {
            memcpy(pptr, (char*)&sendap.ap4data, sizeof(activep4_data_t));
            pptr += sizeof(activep4_data_t);
            ap4len += sizeof(activep4_data_t);
        }

        if(sendap.codelen > 0) {
            memcpy(pptr, (char*)sendap.ap4code, sizeof(activep4_instr) * sendap.codelen);
            pptr += sizeof(activep4_instr) * sendap.codelen;
            ap4len += sizeof(activep4_instr) * sendap.codelen;
        }

        iph = (struct iphdr*)pptr;
        
        iph->ihl = 5;
        iph->version = 4;
        iph->tos = 0;
        iph->tot_len = htons(sizeof(struct iphdr));
        iph->id = htonl(ip_id);
        iph->frag_off = 0;
        iph->ttl = 255;
        iph->protocol = IPPROTO_ICMP;
        iph->check = 0;
        iph->saddr = inet_addr(ipv4_srcaddr);
        iph->daddr = sockin.sin_addr.s_addr;
        
        ip_id++;

        if((sent = sendto(
            sockfd, 
            sendbuf, 
            sizeof(struct ethhdr) + ntohs(iph->tot_len) + ap4len, 
            0, 
            (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr)
        )) < 0) perror("sendto");
        
        //usleep(1E6);
    }

    return 0;
}