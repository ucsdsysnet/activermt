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

#include "../../../../headers/stats.h"

stats_t stats;

static void interrupt_handler(int sig) {
    write_stats(&stats, "kvapp_stats.csv");
    exit(1);
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage: %s -c|-s <ipv4_dstaddr>\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    char* mode = argv[1];
    char* ipv4_dstaddr = argv[2];

    int client_mode = 0;
    if(strcmp(mode, "-c") == 0) client_mode = 1;

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
        while(1) {
            if(recvfrom(s, buf, sizeof(buf), 0, (struct sockaddr *) &client, &client_address_size) < 0) {
                perror("recvfrom()");
                exit(EXIT_FAILURE);
            }
        }
    }

    signal(SIGINT, interrupt_handler);

    memset(&stats, 0, sizeof(stats_t));

    pthread_t timer_thread;

    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
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

    fd_set wr_set;
    int ret;
    uint32_t keys[MAX_KEYS];

    // TODO update with distribution.
    memset(&msg, 0, sizeof(msg));
    for(int i = 0; i < MAX_KEYS; i++) {
        keys[i] = rand() % MAX_KEYS;
        msg[i].iov_base = &keys[i];
        msg[i].iov_len = sizeof(uint32_t);
    }

    int key_current = 0;

    while(1) {

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

    return 0;
}