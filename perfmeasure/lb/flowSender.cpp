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
#include <vector>
#include <fstream>
#include <random>

#define PORT        9876
#define BUFLEN      4096
#define MTU         1450
#define FLAG_ACK    255

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

std::vector<int> getDistFromFile(const std::string& filename) {
  std::vector<int> dist;
  std::ifstream ifs(filename, std::ifstream::in);
  char buf[256];

  while (!ifs.eof()) {
    ifs.getline(buf, sizeof(buf));
    if (buf[0] == '#') {
      continue;
    }
    if (buf[0] == '\n') {
      continue;
    }
    auto size = atoi(buf);
    if (size <= 0) {
      continue;
    }
    dist.push_back(size);
  }
  ifs.close();
  return dist;
}

void adjustTspec(struct timespec *ts) {
    if (ts->tv_sec < 0) {
        ts->tv_sec = 0;
    }
    if (ts->tv_nsec < 0) {
        ts->tv_nsec = 0;
    }
    if (ts->tv_nsec > 999999999) {
        ts->tv_nsec = 999999999;
    }
    if (ts->tv_sec > 20) {
        ts->tv_sec = 10; // XXX HAX Max 10 second sleep.
    }
}

int doSleep(int64_t sleepTimeNsec) {
    if (sleepTimeNsec < 0) {
        sleepTimeNsec = 0;
    }
    int ret;
    struct timespec req, rem;
    auto seconds = sleepTimeNsec / 1000000000L;
    auto nsec = sleepTimeNsec - (seconds * 1000000000L);
    req.tv_sec = static_cast<time_t>(seconds);
    req.tv_nsec = static_cast<long>(nsec);
    do {
        adjustTspec(&req);
        ret = nanosleep(&req, &rem);
        if (ret == -1) {
            if (errno == EINTR) {
                req.tv_sec = rem.tv_sec;
                req.tv_nsec = rem.tv_nsec;
                continue;
            } else if (errno == EFAULT) {
                break;
            } else if (errno == EINVAL) {
                break;
            } else {
                break;
            }
        }
    } while(ret != 0);
    return ret;
}

void

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
        printf("Usage: %s <destination_ip> <flow_dist_file> [duration=10secs]\n", argv[0]);
        exit(1);
    }

    unsigned short fid = 1;

    long experimentDurationSec = 10;
    long sleepDurationAvgNs = 0;
    long sleepDurationStdNs = 0;

    if(argc > 3) experimentDurationSec = atol(argv[3]);

    std::random_device rd;
    std::mt19937 gen(rd());
    std::vector<int> flowSizeBytesList = getDistFromFile(argv[2]);
    std::uniform_int_distribution<> flowIndexDist(0, flowSizeBytesList.size() - 1);

    int* programOffset = (int*) malloc(1 * sizeof(int));
    unsigned char datagram[BUFLEN];
    unsigned char response[BUFLEN];
    memset(datagram, 0, BUFLEN);
    memset(response, 0, BUFLEN);
    datagram[0] = 1;
    datagram[1] = 0;
    datagram[2] = 0;
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

    FILE* fptr = fopen("sender_program.txt", "r");
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

    if(*programOffset > MTU) {
        printf("Program too large to send over network.\n");
        exit(1);
    }
     
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
    sin.sin_addr.s_addr = inet_addr(argv[1]);
    
    uint64_t diff = 0, recvlen;
    socklen_t slen = sizeof(sin);
	struct timespec start, end;

    std::normal_distribution<long double> sleepDist(
        static_cast<long double>(sleepDurationAvgNs),
        static_cast<long double>(sleepDurationStdNs)
    );
    std::uniform_int_distribution<> flowIdxDist(1, 65535);

    long bytesToSend, sentBytes, dataChunk;
    long numInitiatedFlows = 0;
    long numDroppedFlows = 0;
    long numDatagramsSent = 0;
    unsigned short flowId = 0;
    uint64_t expDurationNsec = experimentDurationSec * 1E9;

    std::vector<unsigned short> droppedFlows;
    //unsigned short dummyFlowIds[] = { 1, 8193 };

    printf("Running experiment for %ld seconds...\n", experimentDurationSec);

    while(diff < expDurationNsec) {
        clock_gettime(CLOCK_MONOTONIC, &start);
        // TODO set source port for flows.
        sin.sin_port = htons(PORT);
        flowId = flowIdxDist(gen);
        //flowId = dummyFlowIds[numInitiatedFlows];
        numInitiatedFlows++;
        datagram[10] = (flowId & 0xFF00) >> 8;
        datagram[11] = flowId & 0xFF;
        bytesToSend = flowSizeBytesList[flowIndexDist(gen)];
        sentBytes = 0;
        while(sentBytes < bytesToSend) {
            numDatagramsSent++;
            dataChunk = (bytesToSend - sentBytes > MTU) ? MTU : bytesToSend - sentBytes;
            dataChunk = (dataChunk < *programOffset) ? *programOffset : dataChunk;
            if (sendto (s, datagram, dataChunk,  0, (struct sockaddr *) &sin, sizeof (sin)) < 0)
                perror("sendto failed");
            if ((recvlen = recvfrom(s, response, BUFLEN, 0, (struct sockaddr *) &sin, &slen)) == -1) {
                /*perror("recvfrom failed");
                printf("Culprit: %d\n", flowId);
                exit(1);*/
                numDroppedFlows++;
                droppedFlows.push_back(flowId);
                break;
            } else {
                if(response[1] != FLAG_ACK) {
                    printf("Unknown ack [%d] received!\n", (int) response[1]);
                    exit(1);
                }
            }
            sentBytes += dataChunk;
        }
        //if(numInitiatedFlows > 1) break;
        if(doSleep(static_cast<int64_t>(std::round(sleepDist(gen)))) < 0) {
            printf("SLEEP ERROR\n");
            break;
        }
        clock_gettime(CLOCK_MONOTONIC, &end);
        diff += (end.tv_sec - start.tv_sec) * 1E9 + (end.tv_nsec - start.tv_nsec);
    }

    printf("STATS: %ld flows initiated, %ld flows dropped, %ld datagrams sent.\n", numInitiatedFlows, numDroppedFlows, numDatagramsSent);
    /*FILE *out = fopen("stats.csv", "w");
    fclose(out);
    printf("Dropped flows: 0");
    for(std::vector<unsigned short>::iterator f = droppedFlows.begin(); f != droppedFlows.end(); f++) {
        printf(", %d", *f);
    }
    printf("\n");*/

    return 0;
}
