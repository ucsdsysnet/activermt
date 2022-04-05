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
#include <random>

#define PORT        9876
#define BUFLEN      4096
#define FLAG_ACK    255

int main(int argc, char* argv[]) {

    int s = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);    
    if(s == -1) {
        perror("Failed to create udp socket");
        exit(1);
    }
    int disable = 1;
    if (setsockopt(s, SOL_SOCKET, SO_NO_CHECK, (void*)&disable, sizeof(disable)) < 0) {
        perror("setsockopt failed");
        exit(1);
    }
     
    struct sockaddr_in sin, si_me;
    char datagram[BUFLEN];

    memset(datagram, 0, BUFLEN);
    memset((char *) &si_me, 0, sizeof(si_me));
    memset((char *) &sin, 0, sizeof(sin));
    
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(PORT);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    if( bind(s, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        perror("Failed to bind udp socket");
        exit(1);
    }
    
    socklen_t slen = sizeof(sin);
    int recvlen;
    unsigned short id;

    /*std::random_device rd;
    std::mt19937 gen(rd());
    std::normal_distribution<double> flowDropDist(
        0,
        1000
    );*/
    
    printf("listening on %d\n", PORT);
    while(true) {
        if ((recvlen = recvfrom(s, datagram, BUFLEN, 0, (struct sockaddr *) &sin, &slen)) == -1) {
            perror("recvfrom failed");
        } else {
            /*id = ((unsigned short) datagram[10] << 8) + (unsigned short) datagram[11];
            printf("datagram received for flow %d\n", id);*/
            datagram[1] = FLAG_ACK;
            datagram[9] = 1;
            if (sendto (s, datagram, recvlen,  0, (struct sockaddr *) &sin, sizeof (sin)) < 0)
                perror("sendto failed");
        }
    }

    return 0;
}
