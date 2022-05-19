#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>
#include <arpa/inet.h>
#include <linux/if.h>
#include <sys/socket.h>
#include <sys/ioctl.h>

#define PORT        1234
#define BUFSIZE     1024
#define MAXPINGS    65536    

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("Usage: %s <-c destination | -s> [num_pings]\n", argv[0]);
        exit(1);
    }

    int sockfd;

    if( (sockfd = socket(AF_INET, SOCK_DGRAM, 0)) < 0 ) {
        perror("socket");
        exit(1);
    }

    struct sockaddr_in addr, remote_addr;

    int i, received, num_pings = (argc > 3) ? atoi(argv[3]) : 1;
    uint64_t elapsed_ns = 0;
    uint64_t ping_times[MAXPINGS];
    
    struct timespec ts;
    struct timespec* tsptr;
    char sendbuf[BUFSIZE], recvbuf[BUFSIZE];
    socklen_t addr_len = sizeof(struct sockaddr_in);

    for(i = 0; i < MAXPINGS; i++) ping_times[i] = 0;

    if( strcmp(argv[1], "-c") == 0 ) {
        
        printf("Sending pings...\n");

        remote_addr.sin_family         = AF_INET;
        remote_addr.sin_port           = htons(PORT);
        remote_addr.sin_addr.s_addr    = inet_addr(argv[2]);
        
        for(i = 0; i < num_pings; i++) {
        
            if( clock_gettime(CLOCK_MONOTONIC, &ts) < 0 ) {
                perror("clock_gettime");
                exit(1);
            }
            
            tsptr = (struct timespec*)sendbuf;
            tsptr->tv_sec = ts.tv_sec;
            tsptr->tv_nsec = ts.tv_nsec;
            
            if( sendto(sockfd, sendbuf, sizeof(struct timespec), 0, (struct sockaddr*)&remote_addr, sizeof(remote_addr)) < 0 ) {
                perror("sendto");
                exit(1);
            }

            if( (received = recvfrom(sockfd, recvbuf, BUFSIZE, 0, (struct sockaddr*)&remote_addr, &addr_len)) <= 0 ) {
                perror("recvfrom");
                exit(1);
            }

            if(received < sizeof(struct timespec)) {
                printf("Incorrect value received");
                continue;
            }

            if( clock_gettime(CLOCK_MONOTONIC, &ts) < 0 ) {
                perror("clock_gettime");
                exit(1);
            }

            tsptr = (struct timespec*)recvbuf;
            elapsed_ns = (ts.tv_sec - tsptr->tv_sec) * 1E9 + (ts.tv_nsec - tsptr->tv_nsec);
            ping_times[i] = elapsed_ns;
        }

        close(sockfd);

        FILE* fp = fopen("ping_rtt_ns.csv", "w");
        for(i = 0; i < num_pings; i++) {
            fprintf(fp, "%lu\n", ping_times[i]);
        }
        fclose(fp);

        printf("%d ping times written to file.\n", num_pings);
    } else {
        
        printf("Running server...\n");

        addr.sin_family         = AF_INET;
        addr.sin_port           = htons(PORT);
        addr.sin_addr.s_addr    = INADDR_ANY;

        if( bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0 ) {
            perror("bind");
            exit(1);
        }

        while(1) {
            if( (received = recvfrom(sockfd, recvbuf, BUFSIZE, 0, (struct sockaddr*)&remote_addr, &addr_len)) <= 0 ) {
                perror("recvfrom");
                exit(1);
            }

            memcpy(sendbuf, recvbuf, received);

            if( sendto(sockfd, sendbuf, received, 0, (struct sockaddr*)&remote_addr, sizeof(remote_addr)) < 0 ) {
                perror("sendto");
                exit(1);
            }
        }
    }

    return 0;
}