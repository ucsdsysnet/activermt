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
    struct iovec msg[1];
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

    memset(&msg, 0, sizeof(msg));
    msg[0].iov_base = "GET\nfoo\n";
    msg[0].iov_len = strlen(msg[0].iov_base);
    
    memset(&mhdr, 0, sizeof(mhdr));
    for(int i = 0; i < BURST_SIZE; i++) {
        mhdr[i].msg_hdr.msg_iov = msg;
        mhdr[i].msg_hdr.msg_iovlen = 1;
    }

    fd_set wr_set;
    int ret;

    while(1) {

        FD_ZERO(&wr_set);
        FD_SET(sockfd, &wr_set);

        ret = select(sockfd + 1, NULL, &wr_set, NULL, NULL);

        if(ret < 0 && errno == EINTR) continue;
        if(ret < 0) {
            perror("select()");
            exit(1);
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