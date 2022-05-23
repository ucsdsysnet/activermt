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
#include <pcap.h>

#define PORT                9876
#define BUFLEN              4096
#define STAGE_CACHE_LIMIT   8190
#define NUM_STAGES          4
#define NUM_REQUESTS        65528  
#define MAX_RETRIES         1

//#define DEBUG_CAPTURE

void addInstruction(unsigned char* writeDatagram, int* offset, unsigned char opcode, unsigned short arg, unsigned char gotoLabel) {
    writeDatagram[*offset] = 0;
    writeDatagram[*offset + 1] = opcode;
    writeDatagram[*offset + 2] = (arg & 0xFF00) >> 8;
    writeDatagram[*offset + 3] = arg & 0xFF;
    writeDatagram[*offset + 4] = gotoLabel;
    writeDatagram[*offset + 5] = 2;
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
        exit(1);
    }
    struct timeval tv;
    tv.tv_sec = 0;
    tv.tv_usec = 100000;
    if (setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
        perror("Error");
    }

    if(argc < 3) {
        printf("Usage: %s <destination_ip> <capture_device>\n", argv[0]);
        exit(1);
    }

    char* dev = argv[2];
    char filter_exp[] = "udp";
    char errbuf[PCAP_ERRBUF_SIZE];

    unsigned short fid = 1;

    int* writeProgramOffset = (int*) malloc(1 * sizeof(int));
    int* readProgramOffset = (int*) malloc(1 * sizeof(int));
    unsigned char writeDatagram[BUFLEN], readDatagram[BUFLEN], responseDatagram[BUFLEN];

    memset(writeDatagram, 0, BUFLEN);
    writeDatagram[0] = 1;
    writeDatagram[1] = 0;
    writeDatagram[2] = 0;
    writeDatagram[3] = (fid & 0xFF00) >> 8;
    writeDatagram[4] = fid & 0xFF;
    writeDatagram[5] = 0;
    writeDatagram[6] = 0;
    writeDatagram[7] = 0;
    writeDatagram[8] = 0;
    writeDatagram[9] = 0;
    writeDatagram[10] = 0;
    writeDatagram[11] = 0;
    *writeProgramOffset = 12;

    memset(readDatagram, 0, BUFLEN);
    readDatagram[0] = 1;
    readDatagram[1] = 0;
    readDatagram[2] = 0;
    readDatagram[3] = (fid & 0xFF00) >> 8;
    readDatagram[4] = fid & 0xFF;
    readDatagram[5] = 0;
    readDatagram[6] = 0;
    readDatagram[7] = 0;
    readDatagram[8] = 0;
    readDatagram[9] = 0;
    readDatagram[10] = 0;
    readDatagram[11] = 0;
    *readProgramOffset = 12;

    FILE* fptr = fopen("cache_write.txt", "r");
    if(fptr != NULL) {
        unsigned char opcode, gotoLabel;
        unsigned short arg;
        int count = 0;
        char buf[100];
        while( fgets(buf, 100, fptr) ) {
            opcode = (unsigned char) atoi(getField(strdup(buf), 1));
            arg = (unsigned short) atoi(getField(strdup(buf), 2));
            gotoLabel = (unsigned char) atoi(getField(strdup(buf), 3));
            addInstruction(writeDatagram, writeProgramOffset, opcode, arg, gotoLabel);
            count++;
        }
        printf("Read %d WRITE instructions from file.\n", count);
    }
    fclose(fptr);

    fptr = fopen("cache_read.txt", "r");
    if(fptr != NULL) {
        unsigned char opcode, gotoLabel;
        unsigned short arg;
        int count = 0;
        char buf[100];
        while( fgets(buf, 100, fptr) ) {
            opcode = (unsigned char) atoi(getField(strdup(buf), 1));
            arg = (unsigned short) atoi(getField(strdup(buf), 2));
            gotoLabel = (unsigned char) atoi(getField(strdup(buf), 3));
            addInstruction(readDatagram, readProgramOffset, opcode, arg, gotoLabel);
            count++;
        }
        printf("Read %d READ instructions from file.\n", count);
    }
    fclose(fptr);
     
    struct sockaddr_in sin, si_me;

    memset((char *) &si_me, 0, sizeof(si_me));
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(PORT);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    if( bind(s, (struct sockaddr*)&si_me, sizeof(si_me) ) == -1) {
        perror("Failed to bind udp socket");
        exit(1);
    }
     
    sin.sin_family = AF_INET;
    sin.sin_port = htons(PORT);
    sin.sin_addr.s_addr = inet_addr(argv[1]);

    unsigned short keys[NUM_REQUESTS];
    unsigned short values[NUM_REQUESTS];
    int elapsed[NUM_REQUESTS];
    
    unsigned short key, value, index, acc, acc2;
    uint64_t diff, recvlen;
    struct timespec start, end;
    socklen_t slen = sizeof(sin);
    int retries = 0;

#ifdef DEBUG_CAPTURE
    struct pcap_pkthdr header;
    const u_char *packet;
    pcap_t* handle;
    bpf_u_int32 net;
    struct bpf_program fp;

    handle = pcap_open_live(dev, BUFSIZ, 1, 1000, errbuf);
    if(handle == NULL) {
        printf("Couldn't open device %s!\n", dev);
        exit(1);
    }
    if(pcap_compile(handle, &fp, filter_exp, 0, net) == -1) {
        printf("Couldn't parse filter %s: %s\n", filter_exp, pcap_geterr(handle));
        return(1);
    }
    if(pcap_setfilter(handle, &fp) == -1) {
        printf("Couldn't install filter %s: %s\n", filter_exp, pcap_geterr(handle));
        return(1);
    }
#endif

    for(int stageId = 0; stageId <= NUM_STAGES; stageId++) {

        printf(">>>>> STAGE %d <<<<<\n", stageId);

        memset(keys, 0, NUM_REQUESTS * sizeof(unsigned short));
        memset(values, 0, NUM_REQUESTS * sizeof(unsigned short));
        memset(elapsed, 0, NUM_REQUESTS * sizeof(int));
        memset(responseDatagram, 0, BUFLEN);

        printf("Sending writes...\n");

        for(int i = 0; i < STAGE_CACHE_LIMIT && stageId > 0; i++) {
            key = ((unsigned char) (stageId - 1) << 13) + i + 1;
            value = key - 1;
            writeDatagram[14] = (key & 0xFF00) >> 8;
            writeDatagram[15] = key & 0xFF;
            writeDatagram[20] = (value & 0xFF00) >> 8;
            writeDatagram[21] = value & 0xFF;
            if (sendto (s, writeDatagram, *writeProgramOffset,  0, (struct sockaddr *) &sin, sizeof (sin)) < 0) {
                perror("sendto failed");
                exit(1);
            }
#ifdef DEBUG_CAPTURE
            if(retries > 0) {
                packet = pcap_next(handle, &header);
                printf("Packet detected with length %d\n", header.len);
            }
#endif
            if ((recvlen = recvfrom(s, responseDatagram, BUFLEN, 0, (struct sockaddr *) &sin, &slen)) == -1) {
                perror("recvfrom failed");
                printf("key=%hu\n", key);
                retries++;
                if(retries >= MAX_RETRIES) exit(1);
                usleep(1000);
                printf("retrying...\n");
                i--;
            } else {
                retries = 0;
                key = (((unsigned short) writeDatagram[14]) << 8) + ((unsigned short) writeDatagram[15]);
                //if(responseDatagram[9] == 1) printf("WRITE complete for key %hu\n", key);
            }
        }

        printf("Sending reads...\n");

        for(int j = 0; j < NUM_STAGES; j++) {
            for(int i = 0; i < STAGE_CACHE_LIMIT; i++) {
                index = j * STAGE_CACHE_LIMIT + i + 1;
                key = ((unsigned char) j << 13) + i + 1;
                readDatagram[10] = (index & 0xFF00) >> 8;
                readDatagram[11] = index & 0xFF;
                readDatagram[14] = (key & 0xFF00) >> 8;
                readDatagram[15] = key & 0xFF;
                if (sendto (s, readDatagram, *readProgramOffset,  0, (struct sockaddr*) &sin, sizeof (sin)) < 0)
                    perror("sendto failed");
                clock_gettime(CLOCK_MONOTONIC, &start);
                if ((recvlen = recvfrom(s, responseDatagram, BUFLEN, 0, (struct sockaddr *) &sin, &slen)) == -1) {
                    perror("recvfrom failed");
                    exit(1);
                } else {
                    clock_gettime(CLOCK_MONOTONIC, &end);
                    diff = (1E9 * (end.tv_sec - start.tv_sec) + end.tv_nsec - start.tv_nsec);
                    acc = ((unsigned short) responseDatagram[5] << 8) + (unsigned short) responseDatagram[6];
                    acc2 = ((unsigned short) responseDatagram[7] << 8) + (unsigned short) responseDatagram[8];
                    if(acc > 0 && acc != key) {
                        printf("ERROR: [stage %d : index %d] received key (%hd) does not match sent (%hd)!\n", j, i, acc, key);
                        printf("Sent bytes are [%d,%d]\n", readDatagram[14], readDatagram[15]);
                        exit(1);
                    }
                    keys[index - 1] = acc;
                    values[index - 1] = acc2;
                    elapsed[index - 1] = (int) diff;
                }
            }
        }

        char filename[50];
#ifdef DEBUG_CAPTURE
        sprintf(filename, "/tmp/responses_%d.csv", stageId);
#else
        sprintf(filename, "responses_%d.csv", stageId);
#endif
        FILE *fptr2 = fopen(filename, "w");
        for(long i = 0; i < NUM_REQUESTS; i++) {
            fprintf(fptr2, "%hd,%hd,%d\n", keys[i], values[i], elapsed[i]);
        }
        fclose(fptr2);
        printf("responses written to file %s\n", filename);

        usleep(1000);
    }

#ifdef DEBUG_CAPTURE
    pcap_close(handle);
#endif

    return 0;
}
