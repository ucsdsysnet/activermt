#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <malloc.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <malloc.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#define DEBUG
#define BUFSIZE         16384
#define MAXCONN         256
#define MAXQUEUED       3
#define STATSINTVL_MS   1000

typedef struct {
    int     num_new_conns;
    int     num_active_conns;
    int     num_abrupt_terminations;
    int     num_graceful_terminations;
} stats_t;

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("Usage: %s <port>\n", argv[0]);
        exit(1);
    }

    int     sockfd, conn[MAXCONN], maxfd, i, incoming_conn, addr_len, received, idx;
    char    recvbuf[BUFSIZE];
    fd_set  fd_rd;
    
    struct sockaddr_in bind_addr, conn_addr;

    int opt_reuse = 1;

    int port = atoi(argv[1]);

    bind_addr.sin_family = AF_INET;
    bind_addr.sin_addr.s_addr = INADDR_ANY;
    bind_addr.sin_port = htons(port);

    for(i = 0; i < MAXCONN; i++) {
        conn[i] = 0;
    }

    if( (sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) <= 0 ) {
        perror("socket");
        exit(1);
    }
    if( setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt_reuse, sizeof(opt_reuse)) < 0 ) {
        perror("setsockopt");
        exit(1);
    }
    if( bind(sockfd, (struct sockaddr*)&bind_addr, sizeof(bind_addr)) < 0 ) {
        perror("bind");
        exit(1);
    }
    if( listen(sockfd, MAXQUEUED) < 0 ) {
        perror("listen");
        exit(1);
    }

    printf("Servers listening on %d.\n", port);

    addr_len = sizeof(struct sockaddr_in);

    struct timespec ts_then, ts_now;
    uint64_t elapsed_ms;
    
    stats_t stats = {0, 0, 0, 0};

    if( clock_gettime(CLOCK_MONOTONIC, &ts_then) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    while(1) {

        FD_ZERO(&fd_rd);
        FD_SET(sockfd, &fd_rd);

        maxfd = sockfd;

        for(i = 0; i < MAXCONN; i++) {
            if(conn[i] > 0) FD_SET(conn[i], &fd_rd);
            maxfd = (conn[i] > maxfd) ? conn[i] : maxfd;
        }

        if( select(maxfd + 1, &fd_rd, NULL, NULL, NULL) < 0 && errno != EINTR ) {
            perror("select");
            exit(1);
        }

        idx = -1;
        for(i = 0; i < MAXCONN; i++) {
            if(conn[i] == 0) {
                idx = i;
                break;
            }
        }

        for(i = 0; i < MAXCONN; i++) {
            if(FD_ISSET(conn[i], &fd_rd)) {
                if( (received = recv(conn[i], recvbuf, BUFSIZE, 0)) < 0 ) {
                    //perror("recv");
                    stats.num_abrupt_terminations++;
                    close(conn[i]);
                    conn[i] = 0;
                } else if(received == 0) {
                    stats.num_graceful_terminations++;
                    close(conn[i]);
                    conn[i] = 0;
                }
            }
        }

        if( FD_ISSET(sockfd, &fd_rd) && idx >= 0 ) {
            if( (incoming_conn = accept(sockfd, (struct sockaddr*)&conn_addr, (socklen_t*)&addr_len )) < 0 ) {
                perror("accept");
                exit(1);
            }
            if( fcntl(incoming_conn, F_SETFL, O_NONBLOCK) < 0 ) {
                perror("fcntl");
                exit(1);
            }
            conn[idx] = incoming_conn;
            stats.num_new_conns++;
        }

        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
            perror("clock_gettime");
            exit(1);
        }

        elapsed_ms = (ts_now.tv_sec - ts_then.tv_sec) * 1E3 + (ts_now.tv_nsec - ts_then.tv_nsec) / 1E6;

        if(elapsed_ms >= STATSINTVL_MS) {
            ts_then.tv_sec = ts_now.tv_sec;
            ts_then.tv_nsec = ts_now.tv_nsec;
            for(i = 0; i < MAXCONN; i++) {
                if(conn[i] > 0) stats.num_active_conns++;
            }
            #ifdef DEBUG
            printf("[STATS] %d new, %d active, %d graceful, %d abrupt\n", stats.num_new_conns, stats.num_active_conns, stats.num_graceful_terminations, stats.num_abrupt_terminations);
            #endif
            stats.num_new_conns = 0;
            stats.num_active_conns = 0;
            stats.num_graceful_terminations = 0;
            stats.num_abrupt_terminations = 0;
        }
    }

    return 0;
}