#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <pthread.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/ip.h>

#define BURST_SIZE      32
#define MAX_KEYS        65536
#define DPORT           5678
#define BUFSIZE         2048
#define VLEN            32
#define ITVL_MSEC       1E6
#define NUM_SAMPLES_HM  100000

#include "../../../../headers/stats.h"

typedef struct {
    uint32_t    rx_hits[NUM_SAMPLES_HM];
    uint32_t    rx_total[NUM_SAMPLES_HM];
    uint64_t    ts[NUM_SAMPLES_HM];
    int         num_samples;
} kvapp_stats_t;

stats_t stats;
kvapp_stats_t kv_stats;

int is_running, instance_id;

static void interrupt_handler(int sig) {
    is_running = 0;
    // exit(EXIT_SUCCESS);
}

static void on_shutdown() {
    
    write_stats(&stats, "kvapp_stats.csv");

    char filename[50];
    sprintf(filename, "kv_hits_misses_%d.csv", instance_id);
    FILE* fp = fopen(filename, "w");
    if(fp == NULL) {
        return;
    }
    printf("[INFO] writing hits/misses for %d samples ... \n", kv_stats.num_samples);
    for(int i = 0; i < kv_stats.num_samples; i++) {
        fprintf(fp, "%lu,%u,%u\n", kv_stats.ts[i], kv_stats.rx_hits[i], kv_stats.rx_total[i]);
    }
    fclose(fp);
}

void* rx_loop(void* argp) {
    
    int* sockfd = (int*)argp;

    struct mmsghdr msgs[VLEN];
    struct iovec iovecs[VLEN];
    char bufs[VLEN][BUFSIZE];

    memset(msgs, 0, sizeof(msgs));
    for(int i = 0; i < VLEN; i++) {
        iovecs[i].iov_base         = bufs[i];
        iovecs[i].iov_len          = BUFSIZE;
        msgs[i].msg_hdr.msg_iov    = &iovecs[i];
        msgs[i].msg_hdr.msg_iovlen = 1;
    }

    int num_msgs = 0, KVRESP_LEN = 2 * sizeof(uint32_t);

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    uint32_t rx_hits = 0, rx_total = 0;

    memset(&kv_stats, 0, sizeof(kvapp_stats_t));

    printf("[INFO] RX thread running ... \n");

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}
    while(is_running) {
        if( (num_msgs = recvmmsg(*sockfd, msgs, VLEN, 0, NULL)) < 0) {
            perror("recvmmsg()");
            exit(EXIT_FAILURE);
        }
        for (int i = 0; i < num_msgs; i++) {
            bufs[i][msgs[i].msg_len] = 0;
            if(msgs[i].msg_len == KVRESP_LEN) {
                uint32_t* key = (uint32_t*)bufs[i];
                uint32_t* hm_flag = (uint32_t*)(bufs[i] + sizeof(uint32_t));
                if(*key > 0) {
                    if(*hm_flag == 1) rx_hits++;
                    else if(instance_id == 2) {
                        printf("MISS key %d\n", *key);
                    }
                    rx_total++;
                }
                // printf("[DEBUG] key %u HIT %d\n", *key, *hm_flag);
            }
        }
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        if(elapsed_ns >= ITVL_MSEC && kv_stats.num_samples < NUM_SAMPLES_HM) {
            memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));
            // printf("[DEBUG] rx %u hits %u\n", rx_total, rx_hits);
            kv_stats.rx_hits[kv_stats.num_samples] = rx_hits;
            kv_stats.rx_total[kv_stats.num_samples] = rx_total;
            kv_stats.ts[kv_stats.num_samples] = ts_now.tv_sec * 1E9 + ts_now.tv_nsec;
            kv_stats.num_samples++;
            rx_total = 0;
            rx_hits = 0;
        }
    }
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage: %s -c|-s <ipv4_dstaddr> [instance_id=1]\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    char* mode = argv[1];
    char* ipv4_dstaddr = argv[2];
    
    instance_id = (argc > 3) ? atoi(argv[3]) : 1;

    int client_mode = 0;
    if(strcmp(mode, "-c") == 0) client_mode = 1;

    is_running = 1;

    if(client_mode == 0) {
        int s, namelen, client_address_size;
        struct sockaddr_in client, server;
        char buf[1500];
        if((s = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
            perror("socket()");
            exit(EXIT_FAILURE);
        }
        server.sin_family      = AF_INET;  
        server.sin_port        = DPORT;        
        server.sin_addr.s_addr = INADDR_ANY;
        if(bind(s, (struct sockaddr *)&server, sizeof(server)) < 0) {
            perror("bind()");
            exit(EXIT_FAILURE);
        }
        client_address_size = sizeof(client);
        printf("Running server on port %d ... \n", DPORT);
        while(is_running) {
            if(recvfrom(s, buf, sizeof(buf), 0, (struct sockaddr *) &client, &client_address_size) < 0) {
                perror("recvfrom()");
                exit(EXIT_FAILURE);
            }
        }
    }

    signal(SIGINT, interrupt_handler);

    memset(&stats, 0, sizeof(stats_t));

    pthread_t timer_thread, rx_thread;

    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create(timer_thread)");
        exit(1);
    }

    int sockfd;
    struct sockaddr_in addr;
    struct mmsghdr mhdr[BURST_SIZE];
    struct iovec msg[MAX_KEYS];
    int retval;

    if((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        perror("socket()");
        exit(EXIT_FAILURE);
    }

    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr(ipv4_dstaddr);
    addr.sin_port = htons(DPORT);
    if(connect(sockfd, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
        perror("connect()");
        exit(EXIT_FAILURE);
    }

    if( pthread_create(&rx_thread, NULL, rx_loop, (void*)&sockfd) < 0 ) {
        perror("pthread_create(rx_thread)");
        exit(1);
    }

    fd_set wr_set;
    int ret;
    uint32_t keys[2 * MAX_KEYS];

    memset(keys, 0, 2 * MAX_KEYS * sizeof(uint32_t));

    // TODO update with distribution.
    memset(&msg, 0, sizeof(msg));
    for(int i = 0; i < MAX_KEYS; i++) {
        keys[i*2] = rand() % MAX_KEYS;
        msg[i].iov_base = &keys[i*2];
        msg[i].iov_len = 2 * sizeof(uint32_t);
    }

    int key_current = 0;

    while(is_running) {

        FD_ZERO(&wr_set);
        FD_SET(sockfd, &wr_set);

        ret = select(sockfd + 1, NULL, &wr_set, NULL, NULL);

        if(ret < 0 && errno == EINTR) continue;
        if(ret < 0) {
            perror("select()");
            exit(1);
        }
        
        memset(&mhdr, 0, sizeof(mhdr));
        for(int i = 0; i < BURST_SIZE; i++) {
            mhdr[i].msg_hdr.msg_iov = &msg[key_current];
            mhdr[i].msg_hdr.msg_iovlen = 1;
            key_current = (key_current + 1) % MAX_KEYS;
            // key_current = 32765;
        }

        if(FD_ISSET(sockfd, &wr_set)) {

            if((retval = sendmmsg(sockfd, mhdr, BURST_SIZE, 0)) < 0) {
                perror("sendmmsg()");
                exit(EXIT_FAILURE);
            }
            
            pthread_mutex_lock(&lock);
            stats.count += retval;
            pthread_mutex_unlock(&lock);
        }
    }

    on_shutdown();

    return 0;
}