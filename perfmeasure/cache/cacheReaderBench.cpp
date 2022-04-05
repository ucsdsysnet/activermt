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

#define PORT                9876
#define BUFLEN              4096
#define STAGE_CACHE_LIMIT   8191  
#define NUM_STAGES          8
#define NUM_REQUESTS        65528
#define MAXCONN             10
#define DURATION            1

void addInstruction(unsigned char* datagram, int* offset, unsigned char opcode, unsigned short arg, unsigned char gotoLabel) {
    datagram[*offset] = 0;
    datagram[*offset + 1] = opcode;
    datagram[*offset + 2] = (arg & 0xFF00) >> 8;
    datagram[*offset + 3] = arg & 0xFF;
    datagram[*offset + 4] = gotoLabel;
    datagram[*offset + 5] = 2;
    *offset = *offset + 6;
}

const char* getField(char* line, int num) {
    const char* tok;
    for (tok = strtok(line, ","); tok && *tok; tok = strtok(NULL, ",\n")) {
        if (!--num) return tok;
    }
    return NULL;
}

long long numAckedFlows, numSentFlows;
pthread_mutex_t lock, slock;

typedef struct Config {
    int sock;
    int port;
} config;

config cfg[MAXCONN];
unsigned char datagram[BUFLEN];
int* programOffset;
struct sockaddr_in sin;
bool release;

void setup() {
    for(int i = 0; i < MAXCONN; i++) {
        cfg[i].sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        cfg[i].port = PORT + i;
        if(cfg[i].sock == -1) {
            perror("Failed to create udp socket");
            exit(1);
        }
        int disable = 1;
        if (setsockopt(cfg[i].sock, SOL_SOCKET, SO_NO_CHECK, (void*)&disable, sizeof(disable)) < 0) {
            perror("setsockopt failed");
        }
    }
    printf("sockets set up for %d connections\n", MAXCONN);
}

void *nackReceiver(void *vargp) {
    
    struct sockaddr_in si_me, sock_in;
    socklen_t slen;
    config *c = (config*) vargp;

    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(c->port);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    if( bind(c->sock, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        perror("Failed to bind udp socket");
        exit(1);
    }

    uint64_t recvlen;
    unsigned char response[BUFLEN];
    memset(response, 0, BUFLEN);

    while(true) {
        if ((recvlen = recvfrom(c->sock, response, BUFLEN, 0, (struct sockaddr *) &sock_in, &slen)) == -1) {
            perror("recvfrom failed");
            return NULL;
        } else {
            pthread_mutex_lock(&lock);
            numAckedFlows++;
            pthread_mutex_unlock(&lock);
        }
    }
}

void *flowSender(void *vargp) {
    config *c = (config*) vargp;
    struct timespec start, end;
    uint64_t diff;
    clock_gettime(CLOCK_MONOTONIC, &start);
    diff = 0;
    while(!release);
    while(diff < DURATION * 1E6) {
        if (sendto (c->sock, datagram, *programOffset,  0, (struct sockaddr*) &sin, sizeof (sin)) < 0)
            perror("sendto failed");
        pthread_mutex_lock(&slock);
        numSentFlows++;
        pthread_mutex_unlock(&slock);
        clock_gettime(CLOCK_MONOTONIC, &end);
        diff = (1E9 * (end.tv_sec - start.tv_sec) + end.tv_nsec - start.tv_nsec) / 1000;
    }
}

int main(int argc, char* argv[]) {

    /*struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 100000;
    if (setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        perror("Error");
    }*/

    if(argc < 2) {
        printf("Usage: %s <destination_ip>\n", argv[0]);
        exit(1);
    }

    release = false;

    setup();
    pthread_t receiver[MAXCONN], sender[MAXCONN];
    for(int i = 0; i < MAXCONN; i++) {
        pthread_create(&receiver[i], NULL, nackReceiver, (void*) &cfg[i]);
    }

    unsigned char demand = 0;
    unsigned char flag = 0;
    unsigned short fid = 2;
    unsigned char key = 1;

    programOffset = (int*) malloc(1 * sizeof(int));
    memset(datagram, 0, BUFLEN);
    datagram[0] = 1;
    datagram[1] = flag;
    datagram[2] = demand;
    datagram[3] = (fid & 0xFF00) >> 8;
    datagram[4] = fid & 0xFF;
    datagram[5] = 0;
    datagram[6] = 0;
    datagram[7] = 0;
    datagram[8] = 0;
    datagram[9] = 0;
    datagram[10] = 0;
    datagram[11] = 1;
    *programOffset = 12;
    datagram[14] = (key & 0xFF00) >> 8;
    datagram[15] = key & 0xFF;
    datagram[5] = (key & 0xFF00) >> 8;
    datagram[6] = key & 0xFF;

    FILE* fptr = fopen("cache_read.txt", "r");
    if(fptr != NULL) {
        unsigned char opcode, gotoLabel;
        unsigned short arg;
        int count = 0;
        char buf[100];
        while( fgets(buf, 100, fptr) ) {
            opcode = (unsigned char) atoi(getField(strdup(buf), 1));
            arg = (unsigned short) atoi(getField(strdup(buf), 2));
            gotoLabel = (unsigned char) atoi(getField(strdup(buf), 3));
            addInstruction(datagram, programOffset, opcode, arg, gotoLabel);
            count++;
        }
        printf("Read %d instructions from file.\n", count);
    }
    fclose(fptr);
     
    sin.sin_family = AF_INET;
    sin.sin_port = htons(PORT);
    sin.sin_addr.s_addr = inet_addr(argv[1]);
    
    unsigned short keys[NUM_REQUESTS];
    unsigned short values[NUM_REQUESTS];
    int elapsed[NUM_REQUESTS];

    numSentFlows = 0;
    for(int i = 0; i < MAXCONN; i++) {
        pthread_create(&sender[i], NULL, flowSender, (void*) &cfg[i]);
    }

    release = true;

    for(int i = 0; i < MAXCONN; i++) {
        pthread_join(sender[i], NULL);
    }   

    for(int i = 0; i < MAXCONN; i++) pthread_cancel(receiver[i]);
    pthread_mutex_destroy(&lock);

    printf("%lld flows sent, %lld flows acked\n", numSentFlows, numAckedFlows);

    return 0;
}
