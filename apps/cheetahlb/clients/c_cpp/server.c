#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <malloc.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#define DEBUG
#define MAX_DIST_SIZE   1000
#define BIND_PORT       1234
#define MAXCONN         1000

typedef struct {
    int     dist[MAX_DIST_SIZE];
    int     dist_size;
} flowdist_t;

static inline void read_flowdist(char* filename, flowdist_t* fdist) {
    FILE* fp = fopen(filename, "r");
    int idx = 0, flow_size;
    char buf[50];
    while( fgets(buf, 50, fp) > 0 ) {
        flow_size = atoi(buf);
        if(flow_size > 0) fdist->dist[idx++] = flow_size;
    }
    fdist->dist_size = idx;
    #ifdef DEBUG
    printf("%d flow sizes read from dist file.\n", idx);
    #endif
    fclose(fp);
}

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("Usage %s <flowdist_file>\n", argv[0]);
        exit(1);
    }

    flowdist_t fdist;

    read_flowdist(argv[1], &fdist);

    int     sockfd, maxfd, conn[MAXCONN], i;
    fd_set  fd_rd; 

    for(i = 0; i < MAXCONN; i++) conn[i] = 0;

    if( (sockfd = socket(PF_INET, SOCK_STREAM, 0)) <= 0 ) {
        perror("socket");
        exit(1);
    }

    struct sockaddr_in bind_addr;

    bind_addr.sin_family = AF_INET;
    bind_addr.sin_addr.s_addr = INADDR_ANY;
    bind_addr.sin_port = htons(BIND_PORT);

    if( bind(sockfd, (struct sockaddr*)&bind_addr, sizeof(bind_addr)) < 0 ) {
        perror("bind");
        exit(1);
    }

    if( listen(sockfd, MAXCONN) < 0 ) {
        perror("listen");
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

        //
    }

    return 0;
}