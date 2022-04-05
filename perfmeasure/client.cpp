#include <time.h>
#include <unistd.h>
#include <stdio.h> 
#include <string.h> 
#include <sys/socket.h>
#include <stdlib.h>
#include <errno.h>
#include <netinet/udp.h>
#include <netinet/ip.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define PORT    9876
#define BUFLEN  4096

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

int main(int argc, char* argv[]) {

    int s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);    
    if(s == -1) {
        perror("Failed to create udp socket");
        exit(1);
    }
    int disable = 1;
    if (setsockopt(s, SOL_SOCKET, SO_NO_CHECK, (void*)&disable, sizeof(disable)) < 0) {
        perror("setsockopt failed");
    }
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 100000;
    if (setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        perror("Error");
    }

    if(argc < 3) {
        printf("Usage: %s <program> <destination_ip> [bind_ip] [fid] [demand] [flag]\n", argv[0]);
        exit(1);
    }

    unsigned char demand = 0;
    unsigned char flag = 0;
    unsigned short fid = 1;

    if(argc > 4) fid = (unsigned short) atoi(argv[4]);
    if(argc > 5) demand = (unsigned char) atoi(argv[5]);
    if(argc > 6) flag = (unsigned char) atoi(argv[6]);

    int* programOffset = (int*) malloc(1 * sizeof(int));
    unsigned char datagram[BUFLEN];
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
    datagram[11] = 0;
    *programOffset = 12;

    FILE* fptr = fopen(argv[1], "r");
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
            //printf("%d,%hd,%d\n", opcode, arg, gotoLabel);
            count++;
        }
        printf("Read %d instructions from file.\n", count);
    }
     
    struct sockaddr_in sin, si_me;

    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(PORT);
    if(argc > 3) si_me.sin_addr.s_addr = inet_addr(argv[3]);
    else si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    if( bind(s, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        perror("Failed to bind udp socket");
        exit(1);
    }
     
    sin.sin_family = AF_INET;
    sin.sin_port = htons(PORT);
    sin.sin_addr.s_addr = inet_addr(argv[2]);
    
    uint64_t diff, recvlen;
    socklen_t slen = sizeof(sin);
	struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    if (sendto (s, datagram, *programOffset,  0, (struct sockaddr *) &sin, sizeof (sin)) < 0)
        perror("sendto failed");
    if ((recvlen = recvfrom(s, datagram, BUFLEN, 0, (struct sockaddr *) &sin, &slen)) == -1) {
        perror("recvfrom failed");
    } else {
        clock_gettime(CLOCK_MONOTONIC, &end);
        diff = (1E9 * (end.tv_sec - start.tv_sec) + end.tv_nsec - start.tv_nsec) / 1000;
        printf("Response received after %lu us\n", diff);
        unsigned short acc, acc2;
        acc = ((unsigned short) datagram[5] << 8) + (unsigned short) datagram[6];
        acc2 = ((unsigned short) datagram[7] << 8) + (unsigned short) datagram[8];
        printf("[RESULT] %hd, %hd\n", acc, acc2);
    }

    return 0;
}
