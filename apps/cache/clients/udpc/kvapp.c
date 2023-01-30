#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <pthread.h>
#include <errno.h>
#include <unistd.h>
#include <time.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/ip.h>

#define STATS
#define UNIQUE_KEYS     0
#define MAX_APPS        1024
#define BURST_SIZE      32
#define MAX_KEYS        65536
#define DPORT           5678
#define BUFSIZE         2048
#define VLEN            32
#define ITVL_MSEC       1E6
#define NUM_SAMPLES_HM  100000
#define ZIPF_SIZE       100000

#include "../../../../headers/stats.h"

typedef uint64_t cache_keysize_t;

typedef struct {
    uint32_t    rx_hits[NUM_SAMPLES_HM];
    uint32_t    rx_total[NUM_SAMPLES_HM];
    uint64_t    ts[NUM_SAMPLES_HM];
    int         num_samples;
} kvapp_stats_t;

typedef struct {
    uint16_t        fid;
    unsigned long*  dist;
    int             dist_size;
    kvapp_stats_t*  kv_stats;
    int             sockfd;
} app_context_t;

stats_t stats;

int is_running;

static void interrupt_handler(int sig) {
    is_running = 0;
}

static void on_shutdown(app_context_t* ctxts, int num_apps) {
    
    #ifdef STATS
    write_stats(&stats, "kvapp_stats.csv");
    #endif

    for(int i = 0; i < num_apps; i++) {
        char filename[50];
        sprintf(filename, "kv_hits_misses_%d.csv", ctxts[i].fid);
        FILE* fp = fopen(filename, "w");
        if(fp == NULL) {
            return;
        }
        printf("[INFO] FID %d writing hits/misses for %d samples ... ", ctxts[i].fid, ctxts[i].kv_stats->num_samples);
        for(int j = 0; j < ctxts[i].kv_stats->num_samples; j++) {
            fprintf(
                fp, 
                "%lu,%u,%u\n",
                ctxts[i].kv_stats->ts[j], 
                ctxts[i].kv_stats->rx_hits[j], 
                ctxts[i].kv_stats->rx_total[j]
            );
        }
        fclose(fp);
        printf("done.\n");
    }
}

static inline int compute_unique_keys(uint8_t* bloom) {
    int num_distinct_keys = 0;
    for(int i = 0; i < MAX_KEYS; i++) {
        num_distinct_keys += bloom[i];
    }
    memset(bloom, 0, sizeof(uint8_t) * MAX_KEYS);
    return num_distinct_keys;
}

void* rx_loop(void* argp) {
    
    app_context_t* ctxt = (app_context_t*)argp;

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

    memset(ctxt->kv_stats, 0, sizeof(kvapp_stats_t));

    printf("[INFO] RX thread for FID %d running ... \n", ctxt->fid);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}
    while(is_running) {
        if( (num_msgs = recvmmsg(ctxt->sockfd, msgs, VLEN, 0, NULL)) < 0) {
            perror("recvmmsg()");
            exit(EXIT_FAILURE);
        }
        for (int i = 0; i < num_msgs; i++) {
            bufs[i][msgs[i].msg_len] = 0;
            if(msgs[i].msg_len >= KVRESP_LEN) {
                cache_keysize_t* key = (cache_keysize_t*)bufs[i];
                cache_keysize_t* hm_flag = (cache_keysize_t*)(bufs[i] + sizeof(cache_keysize_t));
                if(*key > 0) {
                    if(*hm_flag == 1) rx_hits++;
                    /*else if(instance_id == 2) {
                        printf("MISS key %d\n", *key);
                    }*/
                    rx_total++;
                }
                // printf("[DEBUG] key %u HIT %d\n", *key, *hm_flag);
            }
        }
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        if(elapsed_ns >= ITVL_MSEC && ctxt->kv_stats->num_samples < NUM_SAMPLES_HM) {
            memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));
            // printf("[DEBUG] rx %u hits %u\n", rx_total, rx_hits);
            ctxt->kv_stats->rx_hits[ctxt->kv_stats->num_samples] = rx_hits;
            ctxt->kv_stats->rx_total[ctxt->kv_stats->num_samples] = rx_total;
            ctxt->kv_stats->ts[ctxt->kv_stats->num_samples] = ts_now.tv_sec * 1E9 + ts_now.tv_nsec;
            ctxt->kv_stats->num_samples++;
            rx_total = 0;
            rx_hits = 0;
        }
        #ifdef STATS
        pthread_mutex_lock(&lock);
        stats.count_alt += num_msgs;
        pthread_mutex_unlock(&lock);
        #endif
    }
}

void* tx_loop(void* argp) {
    
    app_context_t* ctxt = (app_context_t*)argp;

    int sockfd = ctxt->sockfd;
    unsigned long* dist = ctxt->dist;
    int num_keys = ctxt->dist_size;

    printf("[INFO] %d samples in distribution.\n", num_keys);

    struct mmsghdr mhdr[BURST_SIZE];
    struct iovec msg[MAX_KEYS];
    int retval;

    fd_set wr_set;
    int ret, max_iter = 1000;
    cache_keysize_t keys[2 * MAX_KEYS], key;
    uint8_t bloom[MAX_KEYS];

    memset(bloom, 0, MAX_KEYS * sizeof(uint8_t));
    memset(keys, 0, 2 * MAX_KEYS * sizeof(cache_keysize_t));

    memset(&msg, 0, sizeof(msg));
    for(int i = 0; i < MAX_KEYS; i++) {
        // key = rand() % MAX_KEYS;
        key = MAX_KEYS + 1;
        while(key >= MAX_KEYS) {
            key = dist[rand() % num_keys];
            if(UNIQUE_KEYS && bloom[key] == 1) key = MAX_KEYS + 1;
        }
        keys[i*2] = key;
        bloom[key] = 1;
        // printf("%d.\tKey = %u\n", i, key);
        msg[i].iov_base = &keys[i*2];
        msg[i].iov_len = 2 * sizeof(cache_keysize_t);
    }

    printf("[INFO] %d unique keys generated.\n", compute_unique_keys(bloom));

    int key_current = 0;

    printf("[INFO] TX thread for FID %d running ... \n", ctxt->fid);

    #ifdef DEBUG
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}
    #endif

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
            #ifdef DEBUG
            bloom[keys[key_current*2]] = 1;
            #endif
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
            
            #ifdef STATS
            pthread_mutex_lock(&lock);
            stats.count += retval;
            pthread_mutex_unlock(&lock);
            #endif
        }

        #ifdef DEBUG
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        if(elapsed_ns >= 1E9) {
            int num_distinct_keys = compute_unique_keys(bloom);
            printf("[DEBUG] %d keys sent.\n", num_distinct_keys);
            memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));
        }
        #endif
    }
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage: %s <ipv4_dstaddr> <dist_file> [num_instances=1] [stagger_time_sec]\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    char* ipv4_dstaddr = argv[1];
    char* dist_file = argv[2];
    int num_instances = (argc > 3) ? atoi(argv[3]) : 1;
    int stagger_interval_sec = (argc > 4) ? atoi(argv[4]) : 0;

    if(num_instances > MAX_APPS) num_instances = MAX_APPS;

    is_running = 1;

    unsigned long dist[ZIPF_SIZE];

    FILE* fp = fopen(dist_file, "r");
    char buf[100];
    int i = 0;
    while(fgets(buf, 100, fp) != NULL) {
        dist[i++] = atol(buf);
        if(i >= ZIPF_SIZE) break;
    }
    fclose(fp);
    printf("[INFO] read distribution of size %d.\n", i);
    int num_keys = i;

    signal(SIGINT, interrupt_handler);

    app_context_t ctxts[MAX_APPS];

    memset(&stats, 0, sizeof(stats_t));
    memset(ctxts, 0, MAX_APPS * sizeof(app_context_t));

    pthread_t timer_thread, rx_thread[MAX_APPS], tx_thread[MAX_APPS];

    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create(timer_thread)");
        exit(1);
    }

    for(int i = 0; i < num_instances; i++) {

        int sockfd;
        if((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
            perror("socket()");
            exit(EXIT_FAILURE);
        }

        struct sockaddr_in addr;
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr(ipv4_dstaddr);
        addr.sin_port = htons(DPORT + i);
        if(connect(sockfd, (struct sockaddr *) &addr, sizeof(addr)) < 0) {
            perror("connect()");
            exit(EXIT_FAILURE);
        }

        ctxts[i].kv_stats = (kvapp_stats_t*) malloc(sizeof(kvapp_stats_t));
        ctxts[i].dist = dist;
        ctxts[i].dist_size = num_keys;
        ctxts[i].sockfd = sockfd;
        ctxts[i].fid = i + 1;

        if( pthread_create(&rx_thread[i], NULL, rx_loop, (void*)&ctxts[i]) < 0 ) {
            perror("pthread_create(rx_thread)");
            exit(1);
        }

        if( pthread_create(&tx_thread[i], NULL, tx_loop, (void*)&ctxts[i]) < 0 ) {
            perror("pthread_create(tx_thread)");
            exit(1);
        }

        if(stagger_interval_sec > 0) {
            printf("[INFO] staggering for %d seconds ... \n", stagger_interval_sec);
            sleep(stagger_interval_sec);
        }
    }

    for(int i = 0; i < num_instances; i++) {
        pthread_join(tx_thread[i], NULL); // RX threads are blocking.
    }

    on_shutdown(ctxts, num_instances);

    return 0;
}