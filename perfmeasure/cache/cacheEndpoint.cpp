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
#include <map>

#define PORT 9876
#define BUFLEN 4096
#define MAPSIZE 1048576

std::map<unsigned short, unsigned short> memStore;

void initializeStore() {
    for(long i = 0; i < MAPSIZE; i++) {
        memStore.insert(std::pair<unsigned short, unsigned short>(i, i + 1));
    }
}

void getObject(unsigned char* datagram) {
    short fid = (((unsigned short) datagram[3]) << 8) + ((unsigned short) datagram[4]);
    unsigned short arg = (((unsigned short) datagram[5]) << 8) + ((unsigned short) datagram[6]);
    printf("received query [%d,%d] with fid=%d, arg=%d\n", datagram[5], datagram[6], (int) fid, (int) arg);
    if(fid == 2) {
        std::map<unsigned short, unsigned short>::iterator itr = memStore.find(arg);
        if(itr != memStore.end()) {
            printf("found object %hu, %hu\n", itr->first, itr->second);
            /*datagram[5] = (itr->first & 0xFF00) >> 8;
            datagram[6] = itr->first & 0xFF;*/
            datagram[7] = (itr->second & 0xFF00) >> 8;
            datagram[8] = itr->second & 0xFF;
        }
    }
}

int main(int argc, char* argv[]) {

    int s = socket (AF_INET, SOCK_DGRAM, IPPROTO_UDP);    
    if(s == -1) {
        perror("Failed to create udp socket");
        exit(1);
    }
    int disable = 1;
    if (setsockopt(s, SOL_SOCKET, SO_NO_CHECK, (void*)&disable, sizeof(disable)) < 0) {
        perror("setsockopt failed");
    }

    initializeStore();

    unsigned char datagram[BUFLEN];
    memset(datagram, 0, BUFLEN);
     
    struct sockaddr_in sin, si_me;

    memset((char *) &si_me, 0, sizeof(si_me)); 
    memset((char *) &sin, 0, sizeof(sin));

    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(PORT);
    if(argc > 1) si_me.sin_addr.s_addr = inet_addr(argv[1]);
    else si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    if( bind(s, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        perror("Failed to bind udp socket");
        exit(1);
    }
    printf("listening on %d\n", PORT);
    
    unsigned char opcode;
    unsigned short key;
    int recvlen, n, result;
    unsigned long counter = 0;
    socklen_t slen = sizeof(sin);
    while(true) {
        printf("Waiting for request...\n");
        if ((recvlen = recvfrom(s, datagram, BUFLEN, 0, (struct sockaddr *) &sin, &slen)) == -1)
            perror("recvfrom failed");
        getObject(datagram);
        if (sendto (s, datagram, recvlen, 0, (struct sockaddr *) &sin, sizeof (sin)) < 0)
            perror("sendto failed");
        printf("sent data object\n");
        /*opcode = datagram[25];
        if(opcode == 31) {
            key = (((unsigned short) datagram[14]) << 8) + ((unsigned short) datagram[15]);
            printf("[#%lu] WRITE packet received with key %hd\n", ++counter, key);
        } else if(opcode == 32) {
            printf("[#%lu] READ packet received\n", ++counter);
            getObject(datagram);
            if (sendto (s, datagram, recvlen, 0, (struct sockaddr *) &sin, sizeof (sin)) < 0)
                perror("sendto failed");
            printf("sent data object\n");
        } else {
            printf("[#%lu] UNKNOWN packet received\n", ++counter);
        }*/
    }
    
    return 0;
}