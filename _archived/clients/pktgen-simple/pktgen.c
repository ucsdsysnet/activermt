#define _GNU_SOURCE

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
#include <poll.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/queue.h>
#include <sys/mman.h>
#include <linux/if.h>
#include <linux/if_packet.h>
#include <linux/if_ether.h>

#include "../../headers/stats.h"

stats_t stats;

static inline void set_cpu_affinity(int core_id_start, int core_id_end, pthread_t* thread) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    for(int i = core_id_start; i <= core_id_start; i++)
        CPU_SET(i, &cpuset);
    if(pthread_setaffinity_np(*thread, sizeof(cpu_set_t), &cpuset) != 0) {
        perror("pthread_setaffinity()");
    }
}

void* tx_loop(void* argp) {} 

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("Usage: %s <ipv4_dstaddr>\n", argv[0]);
        exit(1);
    }

    char* ipv4_dstaddr = argv[1];

    memset(&stats, 0, sizeof(stats_t));
    pthread_t timer_thread;
    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }
    set_cpu_affinity(40, 40, &timer_thread);

    int sockfd = 0;
    if((sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
        perror("socket()");
        exit(1);
    }

    struct sockaddr_in addr;
    addr.sin_family      = AF_INET;
    addr.sin_port        = 1234;
    addr.sin_addr.s_addr = inet_addr(ipv4_dstaddr);

    char buf[1024] = "Hello!";

    while(1) {
        if(sendto(sockfd, buf, strlen(buf) + 1, 0, (struct sockaddr*)&addr, sizeof(struct sockaddr_in)) < 0) {
            perror("sendto()");
            exit(1);
        }
    }

    pthread_join(timer_thread, NULL);

    return 0;
}