#define _GNU_SOURCE

#define TRUE            1
#define STATS_ITVL_NS   1E9
#define MAX_SAMPLES     10000
#define BUFSIZE         1450
#define NUM_THREADS     16

#define REDIS_REQ       1

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <sys/types.h> 
#include <sys/socket.h> 
#include <arpa/inet.h> 
#include <netinet/in.h> 
#include <hiredis.h>

#include "../../../../headers/stats.h"

stats_t stats;

static void interrupt_handler(int sig) {
    write_stats(&stats, "redisapp_stats.csv");
    exit(1);
}

static inline void set_cpu_affinity(int core_id_start, int core_id_end, pthread_t* thread) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    for(int i = core_id_start; i <= core_id_start; i++)
        CPU_SET(i, &cpuset);
    if(pthread_setaffinity_np(*thread, sizeof(cpu_set_t), &cpuset) != 0) {
        perror("pthread_setaffinity()");
    }
}

void* request_sender(void* argp) {

    char* ipv4_dstaddr = (char*)argp;

    redisContext *c = redisConnect(ipv4_dstaddr, 6379);
    if(c == NULL || c->err) {
        if (c) {
            printf("Error: %s\n", c->errstr);
            exit(1);
        } else {
            printf("Can't allocate redis context.\n");
        }
    }

    while(TRUE) {
        redisReply* reply = (redisReply*)redisCommand(c, "GET foo");
        assert(reply->str!= NULL && strcmp(reply->str, "bar") == 0);
        freeReplyObject(reply);
        pthread_mutex_lock(&lock);
        stats.count++;
        pthread_mutex_unlock(&lock);
    }
}

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("Usage: %s <ipv4_dstaddr>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    char* ipv4_dstaddr = argv[1];

    signal(SIGINT, interrupt_handler);

    memset(&stats, 0, sizeof(stats_t));

    /*#ifndef REDIS_REQ
    int sockfd;
    char sendbuf[BUFSIZE];
    struct sockaddr_in addr;
    uint64_t* data;

    if( (sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0 ) { 
        perror("socket()"); 
        exit(1); 
    }

    memset(&addr, 0, sizeof(struct sockaddr_in));

    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr(ipv4_dstaddr);
    addr.sin_port = htons(1234);

    memset(sendbuf, 0, BUFSIZE);
    #endif

    #ifdef REDIS_REQ
    redisContext *c = redisConnect(ipv4_dstaddr, 6379);
    if(c == NULL || c->err) {
        if (c) {
            printf("Error: %s\n", c->errstr);
            exit(1);
        } else {
            printf("Can't allocate redis context.\n");
        }
    }
    #endif*/

    pthread_t timer_thread;

    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    /*while(TRUE) {
        #ifndef REDIS_REQ
        data = (uint64_t*) sendbuf;
        (*data)++;
        if( sendto(sockfd, sendbuf, sizeof(uint64_t), MSG_CONFIRM, (struct sockaddr*)&addr, sizeof(struct sockaddr)) < 0 ) {
            perror("sendto()");
            exit(1);
        }
        #else
        redisReply* reply = (redisReply*)redisCommand(c, "GET foo");
        assert(reply->str!= NULL && strcmp(reply->str, "bar") == 0);
        freeReplyObject(reply);
        #endif
        pthread_mutex_lock(&lock);
        stats.count++;
        pthread_mutex_unlock(&lock);
        //usleep(1);
    }*/

    pthread_t request_thread[NUM_THREADS];
    for(int i = 0; i < NUM_THREADS; i++) {
        if( pthread_create(&request_thread[i], NULL, request_sender, (void*)ipv4_dstaddr) < 0 ) {
            perror("pthread_create()");
            exit(1);
        }
        set_cpu_affinity(20 + i*2, 20 + i*2, &request_thread[i]);
    }

    for(int i = 0; i < NUM_THREADS; i++)
        pthread_join(request_thread[i], NULL);
    pthread_join(timer_thread, NULL);

    return 0;
}