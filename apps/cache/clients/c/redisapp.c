#define TRUE            1
#define STATS_ITVL_NS   1E9
#define MAX_SAMPLES     10000
#define BUFSIZE         1450

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

int main(int argc, char** argv) {

    char* ipv4_dstaddr = "192.168.0.2";

    if(argc > 1) {
        ipv4_dstaddr = argv[1];
    }

    signal(SIGINT, interrupt_handler);

    memset(&stats, 0, sizeof(stats_t));

    #ifndef REDIS_REQ
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
    #endif

    pthread_t timer_thread;

    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    while(TRUE) {
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
    }

    pthread_join(timer_thread, NULL);

    return 0;
}