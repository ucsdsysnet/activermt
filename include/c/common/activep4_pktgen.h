/**
 * @file activep4_pktgen.h
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

#ifndef ACTIVEP4_PKTGEN_H
#define ACTIVEP4_PKTGEN_H

#define NUM_STAGES      20
#define IPADDRSIZE      16
#define BUFSIZE         16384
#define QUEUELEN        8192
#define ETHTYPE_AP4     0x83B2
#define ETHTYPE_IP      0x0800

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

#include "activep4.h"
#include "stats.h"

typedef struct {
    activep4_ih             ap4ih;
    activep4_data_t         ap4data;
    activep4_instr          ap4code[MAXPROGLEN];
    int                     codelen;
    activep4_malloc_req_t   ap4malloc;
    activep4_malloc_res_t   ap4alloc;
} active_program_t;

typedef struct {
    int                 head;
    int                 tail;
    active_program_t    program[QUEUELEN];
} active_queue_t;

static inline void init_queue(active_queue_t* queue) {
    queue->head = -1;
    queue->tail = -1;
}

static inline int is_queue_empty(active_queue_t* queue) {
    if(queue->head == -1) return 1;
    else return 0;
}

static inline int enqueue_program(active_queue_t* queue, active_program_t* program) {
    if((queue->head >=0 && queue->tail == QUEUELEN - 1) || (queue->head == queue->tail + 1)) {
        printf("Queue overflow!\n");
        return -1;
    }
    if(queue->head == -1) queue->head = 0;
    queue->tail = (queue->tail + 1) % QUEUELEN;
    memcpy((char*)&queue->program[queue->tail], (char*)program, sizeof(active_program_t));
    return queue->tail;
}

static inline active_program_t* dequeue_program(active_queue_t* queue) {
    if(queue->head == -1) {
        printf("Queue underflow!\n");
        return NULL;
    }
    active_program_t* program = &queue->program[queue->head];
    if(queue->head == queue->tail) {
        queue->head = -1;
        queue->tail = -1;
    } else queue->head = (queue->head + 1) % QUEUELEN;
    return program;
}

/* Global data structures for rx/tx. */

int sockfd;

devinfo_t dev_info;

struct sockaddr_in sockin;

struct sockaddr_ll eth_dst_addr = {0};
struct sockaddr_ll addr = {0};

char ipv4_src[IPADDRSIZE];
unsigned char eth_dst[ETH_ALEN];

uint16_t ip_id;

/* RX/TX functions. */

void on_active_pkt_recv(struct ethhdr* eth, struct iphdr* iph, activep4_ih* ap4ih, activep4_data_t* ap4data, activep4_malloc_res_t* ap4alloc);

static void rx_tx_init(char* eth_iface, char* ipv4_srcaddr, char* ipv4_dstaddr, unsigned char* eth_dstmac) {

    strcpy(ipv4_src, ipv4_srcaddr);
    memcpy(eth_dst, eth_dstmac, ETH_ALEN);

    ip_id = (uint16_t)rand();

    sockin.sin_family = AF_INET;
    sockin.sin_port = htons(1234);
    sockin.sin_addr.s_addr = inet_addr(ipv4_dstaddr);

    if((sockfd = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket");
        exit(1);
    }

    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;
    //setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, (const char*)&tv, sizeof(tv));

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
}

static int active_tx(active_program_t* program) {
    
    int ap4len, i, sent;
    char sendbuf[BUFSIZE];

    struct ethhdr*      eth;
    struct iphdr*       iph;
    activep4_ih*        ap4ih;
    activep4_data_t*    ap4data;

    uint16_t ap4_flags;
    char* pptr;

    memset(sendbuf, 0, BUFSIZE);
    pptr = sendbuf;

    eth = (struct ethhdr*)pptr;

    memcpy(&eth->h_source, &dev_info.hwaddr, ETH_ALEN);
    memcpy(&eth->h_dest, eth_dst, ETH_ALEN);
    eth->h_proto = htons(ETHTYPE_AP4);

    memcpy(eth_dst_addr.sll_addr, eth_dst, ETH_ALEN);

    pptr += sizeof(struct ethhdr);

    ap4len = sizeof(activep4_ih);

    memcpy(pptr, (char*)&program->ap4ih, sizeof(activep4_ih));
    
    pptr += sizeof(activep4_ih);

    if((ntohs(program->ap4ih.flags) & AP4FLAGMASK_FLAG_REQALLOC) > 0) {
        memcpy(pptr, (char*)&program->ap4malloc, sizeof(activep4_malloc_req_t));
        pptr += sizeof(activep4_malloc_req_t);
        ap4len += sizeof(activep4_malloc_req_t);
    }

    if((ntohs(program->ap4ih.flags) & AP4FLAGMASK_OPT_ARGS) > 0) {
        memcpy(pptr, (char*)&program->ap4data, sizeof(activep4_data_t));
        pptr += sizeof(activep4_data_t);
        ap4len += sizeof(activep4_data_t);
    }

    if(program->codelen > 0) {
        for(i = 0; i < program->codelen; i++) {
            memcpy(pptr, (char*)&program->ap4code[i], sizeof(activep4_instr));
            pptr += sizeof(activep4_instr);
            ap4len += sizeof(activep4_instr);
        }
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
    iph->saddr = inet_addr(ipv4_src);
    iph->daddr = sockin.sin_addr.s_addr;
    
    ip_id++;

    iph->check = compute_checksum((uint16_t*)iph, iph->tot_len);

    //memcpy(pptr, (char*)iph, ntohs(iph->tot_len));

    if((sent = sendto(
        sockfd, 
        sendbuf, 
        sizeof(struct ethhdr) + ntohs(iph->tot_len) + ap4len, 
        0, 
        (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr)
    )) < 0) perror("sendto");

    pthread_mutex_lock(&lock);
    stats.count++;
    pthread_mutex_unlock(&lock);

    return sent;
}

static int active_rx(active_program_t* program) {

    char recvbuf[BUFSIZE];

    struct ethhdr*          eth;
    struct iphdr*           iph;
    activep4_ih*            ap4ih;
    activep4_data_t*        ap4data;
    activep4_malloc_res_t*  ap4alloc;

    int ret, read_bytes, ap4_offset;

    uint16_t ap4_flags;

    char* pptr;

    memset(program, 0, sizeof(active_program_t));

    read_bytes = read(sockfd, recvbuf, sizeof(recvbuf));

    if(read_bytes < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
        printf("rx timed out.\n");
        return errno;
    }

    eth = (struct ethhdr*)recvbuf;

    #ifdef DEBUG
    printf("<< FRAME: %d bytes from protocol 0x%hx\n", read_bytes, ntohs(eth->h_proto));
    print_hwaddr(eth->h_dest);
    #endif
    
    if(!hwaddr_equals(eth->h_dest, eth_dst)) {
        if(ntohs(eth->h_proto) == ETHTYPE_AP4) {
            pptr = recvbuf + sizeof(struct ethhdr);
            ap4ih = NULL;
            if(is_activep4(pptr)) {
                ap4ih = (activep4_ih*) pptr;
                ap4_flags = ntohs(ap4ih->flags);
                pptr += sizeof(activep4_ih);
                #ifdef DEBUG
                printf("FLAGS %x\n", ap4_flags);
                #endif
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
                memcpy(&program->ap4ih, (char*)ap4ih, sizeof(activep4_ih));
            }
        }
    }

    return 0;
}

static void active_rx_tx(active_queue_t* queue, char* ipv4_srcaddr, char* ipv4_dstaddr, unsigned char* eth_dstmac) {

    fd_set rd_set;

    struct ethhdr*      eth;
    struct iphdr*       iph;
    activep4_ih*        ap4ih;
    activep4_data_t*    ap4data;
    
    activep4_malloc_res_t* ap4alloc;

    uint16_t ap4_flags;

    int ret, read_bytes, ap4_offset, maxfd = sockfd;

    char recvbuf[BUFSIZE], sendbuf[BUFSIZE];

    char* pptr;

    struct timeval timeout_select;
    timeout_select.tv_sec = 0;
    timeout_select.tv_usec = 0;

    while(TRUE) {
        
        FD_ZERO(&rd_set);
        FD_SET(sockfd, &rd_set);

        ret = select(maxfd + 1, &rd_set, NULL, NULL, &timeout_select);

        if(ret < 0 && errno == EINTR) continue;

        if(ret < 0) {
            perror("select");
            exit(1);
        }

        if(FD_ISSET(sockfd, &rd_set)) {
            read_bytes = read(sockfd, recvbuf, sizeof(recvbuf));
            eth = (struct ethhdr*)recvbuf;
            #ifdef DEBUG
            printf("<< FRAME: %d bytes from protocol 0x%hx\n", read_bytes, ntohs(eth->h_proto));
            print_hwaddr(eth->h_dest);
            #endif
            if(!hwaddr_equals(eth->h_dest, eth_dstmac)) {
                if(ntohs(eth->h_proto) == ETHTYPE_AP4) {
                    pptr = recvbuf + sizeof(struct ethhdr);
                    ap4ih = NULL;
                    if(is_activep4(pptr)) {
                        ap4ih = (activep4_ih*) pptr;
                        ap4_flags = ntohs(ap4ih->flags);
                        pptr += sizeof(activep4_ih);
                        #ifdef DEBUG
                        printf("FLAGS %x\n", ap4_flags);
                        #endif
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
                        on_active_pkt_recv(eth, iph, ap4ih, ap4data, ap4alloc);
                    }
                }
            }
            // if(hwaddr_equals(eth->h_dest, dev_info.hwaddr)) {}
        }

        active_program_t* program;
        int ap4len, i;

        if(!is_queue_empty(queue)) {
            
            program = dequeue_program(queue);
            if(program == NULL) {
                printf("queue corrupted.\n");
                exit(1);
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

            memcpy(pptr, (char*)&program->ap4ih, sizeof(activep4_ih));
            
            pptr += sizeof(activep4_ih);

            if((ntohs(program->ap4ih.flags) & AP4FLAGMASK_FLAG_REQALLOC) > 0) {
                memcpy(pptr, (char*)&program->ap4malloc, sizeof(activep4_malloc_req_t));
                pptr += sizeof(activep4_malloc_req_t);
                ap4len += sizeof(activep4_malloc_req_t);
            }

            if((ntohs(program->ap4ih.flags) & AP4FLAGMASK_OPT_ARGS) > 0) {
                memcpy(pptr, (char*)&program->ap4data, sizeof(activep4_data_t));
                pptr += sizeof(activep4_data_t);
                ap4len += sizeof(activep4_data_t);
            }

            if(program->codelen > 0) {
                for(i = 0; i < program->codelen; i++) {
                    memcpy(pptr, (char*)&program->ap4code[i], sizeof(activep4_instr));
                    pptr += sizeof(activep4_instr);
                    ap4len += sizeof(activep4_instr);
                }
                //memcpy(pptr, (char*)&program->ap4code, sizeof(activep4_instr) * program->codelen);
                //pptr += sizeof(activep4_instr) * program->codelen;
                //ap4len += sizeof(activep4_instr) * program->codelen;
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

            iph->check = compute_checksum((uint16_t*)iph, iph->tot_len);

            memcpy(pptr, (char*)iph, ntohs(iph->tot_len));

            if(sendto(
                sockfd, 
                sendbuf, 
                sizeof(struct ethhdr) + ntohs(iph->tot_len) + ap4len, 
                0, 
                (struct sockaddr*)&eth_dst_addr, sizeof(eth_dst_addr)
            ) < 0) perror("sendto");
        }
    }
}

#endif