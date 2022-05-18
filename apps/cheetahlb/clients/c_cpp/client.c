#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <malloc.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#define DEBUG
#define MAX_DIST_SIZE   1000
#define BUFSIZE         16384
#define MAXMSGSIZE      8192
#define MAXCONN         1
#define LINGER_TO       0
#define STATSINTVL_MS   1000

typedef struct {
    int     dist[MAX_DIST_SIZE];
    int     dist_size;
} flowdist_t;

typedef struct {
    int                 sockfd;
    int                 bytes_to_send;
    int                 bytes_sent;
    struct sockaddr_in  conn_addr;
} conn_t;

typedef struct {
    int         num_new_conns;
    int         num_active_conns;
    int         num_abrupt_terminations;
    int         num_graceful_terminations;
    int         num_errors;
} stats_t;

static inline int read_flowdist(char* filename, flowdist_t* fdist) {
    FILE* fp = fopen(filename, "r");
    int idx = 0, flow_size, max_flowsize = 0;
    char buf[50];
    while( fgets(buf, 50, fp) > 0 ) {
        flow_size = atoi(buf);
        if(flow_size > 0) {
            fdist->dist[idx++] = flow_size;
            max_flowsize = (flow_size > max_flowsize) ? flow_size : max_flowsize;
        }
    }
    fdist->dist_size = idx;
    #ifdef DEBUG
    printf("%d flow sizes read from dist file.\n", idx);
    #endif
    fclose(fp);
    return max_flowsize;
}

static inline void re_connect(conn_t* conn, stats_t* stats) {
    int opt_reuse = 1;
    struct linger so_linger;
    so_linger.l_onoff = 1;
    so_linger.l_linger = LINGER_TO;
    if(conn->sockfd > 0) close(conn->sockfd);
    conn->sockfd = 0;
    if( (conn->sockfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) < 0 ) {
        perror("socket");
        exit(1);
    }
    if( setsockopt(conn->sockfd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt_reuse, sizeof(opt_reuse)) < 0 ) {
        perror("setsockopt");
        exit(1);
    }
    if( setsockopt(conn->sockfd, SOL_SOCKET, SO_LINGER, &so_linger, sizeof(so_linger)) < 0 ) {
        perror("setsockopt");
        exit(1);
    }
    if( fcntl(conn->sockfd, F_SETFL, O_NONBLOCK) < 0 ) {
        perror("fcntl");
        exit(1);
    }
    if( connect(conn->sockfd, (struct sockaddr*)&conn->conn_addr, sizeof(struct sockaddr_in)) < 0 && errno != EINPROGRESS ) {
        perror("connect");
        close(conn->sockfd);
        conn->sockfd = 0;
        stats->num_errors++;
    } else {
        stats->num_new_conns++;
    }
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage %s <server_addr> <port> [flowdist_file]\n", argv[0]);
        exit(1);
    }

    flowdist_t fdist;

    int port = atoi(argv[2]);

    int max_flowsize = (argc > 3) ? read_flowdist(argv[3], &fdist) : MAXMSGSIZE;

    int     i, maxfd, outgoing_conn, idx, msg_size, received, sent;
    char    sendbuf[BUFSIZE], recvbuf[BUFSIZE], ipaddr[15];
    conn_t  conn[MAXCONN];
    fd_set  fd_rd, fd_wr;

    stats_t stats = {0, 0, 0, 0, 0};

    struct timespec ts_then, ts_now;
    uint64_t elapsed_ms;

    #ifdef DEBUG
    printf("Initiating %d connections...\n", MAXCONN);
    #endif

    for(i = 0; i < MAXCONN; i++) {
        conn[i].bytes_to_send = 0;
        conn[i].bytes_sent = 0;
        conn[i].conn_addr.sin_family = AF_INET;
        conn[i].conn_addr.sin_port = htons(port);
        conn[i].conn_addr.sin_addr.s_addr = inet_addr(argv[1]);
        re_connect(&conn[i], &stats);
    }

    if( clock_gettime(CLOCK_MONOTONIC, &ts_then) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    while(1) {
        
        FD_ZERO(&fd_rd);
        FD_ZERO(&fd_wr);

        maxfd = 0;

        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
            perror("clock_gettime");
            exit(1);
        }

        elapsed_ms = (ts_now.tv_sec - ts_then.tv_sec) * 1E3 + (ts_now.tv_nsec - ts_then.tv_nsec) / 1E6;

        if(elapsed_ms >= STATSINTVL_MS) {
            ts_then.tv_sec = ts_now.tv_sec;
            ts_then.tv_nsec = ts_now.tv_nsec;
            for(i = 0; i < MAXCONN; i++) {
                if(conn[i].sockfd > 0) stats.num_active_conns++;
            }
            #ifdef DEBUG
            printf("[STATS] %d new, %d active, %d graceful, %d abrupt, %d errors\n", stats.num_new_conns, stats.num_active_conns, stats.num_graceful_terminations, stats.num_abrupt_terminations, stats.num_errors);
            #endif
            stats.num_new_conns = 0;
            stats.num_active_conns = 0;
            stats.num_abrupt_terminations = 0;
            stats.num_graceful_terminations = 0;
            stats.num_errors = 0;
        }

        maxfd = 0;

        for(i = 0; i < MAXCONN; i++) {
            if(conn[i].sockfd > 0) {
                FD_SET(conn[i].sockfd, &fd_rd);
                FD_SET(conn[i].sockfd, &fd_wr);
            } else {
                re_connect(&conn[i], &stats);
            }
            maxfd = (conn[i].sockfd > maxfd) ? conn[i].sockfd : maxfd;
        }

        if( select(maxfd + 1, &fd_rd, &fd_wr, NULL, NULL) < 0 && errno != EINTR ) {
            perror("select");
            exit(1);
        }

        for(i = 0; i < MAXCONN; i++) {

            if(FD_ISSET(conn[i].sockfd, &fd_rd)) {
                if( (received = recv(conn[i].sockfd, recvbuf, BUFSIZE, 0)) < 0 && errno != ENOTCONN ) {
                    perror("recv");
                    re_connect(&conn[i], &stats);
                    stats.num_abrupt_terminations++;
                } else if(received == 0) {
                    re_connect(&conn[i], &stats);
                    stats.num_graceful_terminations++;
                }
            }

            if(FD_ISSET(conn[i].sockfd, &fd_wr)) {
                msg_size = conn[i].bytes_to_send - conn[i].bytes_sent;
                if(msg_size > 0) {
                    msg_size = (msg_size < BUFSIZE) ? msg_size : BUFSIZE;
                    memset(sendbuf, 'a', msg_size);
                    if( (sent = send(conn[i].sockfd, sendbuf, msg_size, 0)) < 0 ) {
                        if(errno != EWOULDBLOCK || errno != EAGAIN) {
                            perror("send");
                            exit(1);
                        }
                    } else {
                        conn[i].bytes_sent += sent;
                    }
                }
            }

            if(conn[i].bytes_sent >= conn[i].bytes_to_send) {
                re_connect(&conn[i], &stats);
                //idx = rand() % fdist.dist_size;
                //conn[i].bytes_to_send = fdist.dist[idx];
                conn[i].bytes_to_send = MAXMSGSIZE;
                conn[i].bytes_sent = 0;
            }
        }
    }
    
    return 0;
}