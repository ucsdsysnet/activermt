#include <time.h>
#include <unistd.h>
#include <stdio.h> 
#include <string.h> 
#include <sys/socket.h>
#include <stdlib.h>
#include <errno.h>
#include <pthread.h> 
#include <netinet/udp.h>
#include <netinet/ip.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define PORT_START  9876
#define BUFLEN      4096
#define MAXCONN     8192

void *worker(void *vargp) {

    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);    
    if(sock == -1) {
        perror("Failed to create udp socket");
        exit(1);
    }
    
    struct sockaddr_in si_me, sock_in;
    socklen_t slen;
    uint64_t recvlen;
    int *port = (int*) vargp;
    unsigned char response[BUFLEN];
    memset(response, 0, BUFLEN);

    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(*port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    if( bind(sock, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        perror("Failed to bind udp socket");
        exit(1);
    }

    while(true) {
        if((recvlen = recvfrom(sock, response, BUFLEN, 0, (struct sockaddr *) &sock_in, &slen)) == -1) {
            perror("recvfrom failed");
        } else {
            printf("datagram received\n");
        }
    }

    return NULL;
}

int main(int argc, char* argv[]) {

    if(argc < 2) {
        printf("Usage: %s <num_connections>\n", argv[0]);
        exit(1);
    }

    int numConnections = atoi(argv[1]);
    if(numConnections > MAXCONN) numConnections = MAXCONN;

    printf("Using %d connections\n", numConnections);

    pthread_t *workers = (pthread_t*) malloc(numConnections * sizeof(pthread_t));
    int *ports = (int*) malloc(numConnections * sizeof(int));

    for(int i = 0; i < numConnections; i++) {
        ports[i] = PORT_START + i;
        pthread_create(&workers[i], NULL, worker, (void*) &ports[i]);
    }

    printf("started all workers\n");

    sleep(3);

    for(int i = 0; i < numConnections; i++) {
        pthread_cancel(workers[i]);
    }

    return 0;
}