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
#include <vector>
#include <fstream>
#include <random>
#include <map>

#define PORT        9877
#define BUFLEN      4096
#define MTU         1450
#define FLAG_ACK    255
#define MAXCONN     5000
#define NUMFLOWS    10000

typedef struct Config {
    int sock;
    int port;
} config;

config cfg[MAXCONN];
int programLength, tailerLength;
long experimentDurationSec, sleepDurationAvgNs, sleepDurationStdNs;
long numFlowsPerWorker;
unsigned char datagram[BUFLEN], tailer[BUFLEN];
char* destination;
bool wait;
pthread_mutex_t lock;

std::random_device rd;
std::mt19937 gen(rd());
std::vector<int> flowSizeBytesList;

long numInitiatedFlows, numDroppedFlows, numDatagramsSent;
unsigned long long numBytesSent;

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

    std::map<unsigned short, bool> droppedFlows;
    uint64_t recvlen;
    unsigned short acc, flowId;
    unsigned char response[BUFLEN];
    memset(response, 0, BUFLEN);

    while(true) {
        if ((recvlen = recvfrom(c->sock, response, BUFLEN, 0, (struct sockaddr *) &sock_in, &slen)) == -1) {
            perror("recvfrom failed");
            return NULL;
        } else {
            acc = ((unsigned short) response[5] << 8) + (unsigned short) response[6];
            flowId = ((unsigned short) response[10] << 8) + (unsigned short) response[11];
            pthread_mutex_lock(&lock);
            if(acc == 255 && droppedFlows.find(flowId) == droppedFlows.end()) {
                numDroppedFlows++;
                droppedFlows.insert(std::pair<unsigned short, bool>(flowId, true));
            }
            pthread_mutex_unlock(&lock);
        }
    }
}

void *flowSender(void *vargp) {

    struct sockaddr_in sock_in;
    config *c = (config*) vargp;
     
    sock_in.sin_family = AF_INET;
    sock_in.sin_addr.s_addr = inet_addr(destination);
    sock_in.sin_port = htons(PORT);

    uint64_t diff = 0;
    socklen_t slen = sizeof(sock_in);
	struct timespec start, end;

    std::normal_distribution<long double> sleepDist(
        static_cast<long double>(sleepDurationAvgNs),
        static_cast<long double>(sleepDurationStdNs)
    );
    std::uniform_int_distribution<> flowIdxDist(1, 65535);
    std::uniform_int_distribution<> flowIndexDist(0, flowSizeBytesList.size() - 1);

    long bytesToSend, sentBytes, dataChunk;
    unsigned short flowId = 0;
    uint64_t expDurationNsec = experimentDurationSec * 1E9;

    unsigned char request[BUFLEN];
    memcpy(request, datagram, BUFLEN);

    while(wait) {
        sleep(0);
    }

    for(long i = 0; i < numFlowsPerWorker; i++) {
        clock_gettime(CLOCK_MONOTONIC, &start);
        flowId = flowIdxDist(gen);
        pthread_mutex_lock(&lock);
        numInitiatedFlows++;
        pthread_mutex_unlock(&lock);
        request[10] = (flowId & 0xFF00) >> 8;
        request[11] = flowId & 0xFF;
        bytesToSend = flowSizeBytesList[flowIndexDist(gen)];
        sentBytes = 0;
        while(sentBytes < bytesToSend) {
            numDatagramsSent++;
            dataChunk = (bytesToSend - sentBytes > MTU) ? MTU : bytesToSend - sentBytes;
            dataChunk = (dataChunk < programLength) ? programLength : dataChunk;
            if (sendto (c->sock, request, dataChunk,  0, (struct sockaddr *) &sock_in, sizeof (sock_in)) < 0)
                perror("sendto failed");
            sentBytes += dataChunk;
        }
        numBytesSent += sentBytes;
        request[1] = 6;
        if (sendto (c->sock, request, programLength,  0, (struct sockaddr *) &sock_in, sizeof (sock_in)) < 0)
            perror("sendto failed");
        request[1] = 0;
        /*tailer[10] = (flowId & 0xFF00) >> 8;
        tailer[11] = flowId & 0xFF;
        if (sendto (c->sock, tailer, programLength,  0, (struct sockaddr *) &sock_in, sizeof (sock_in)) < 0)
            perror("sendto failed");*/
        if(doSleep(static_cast<int64_t>(std::round(sleepDist(gen)))) < 0) {
            printf("SLEEP ERROR\n");
            break;
        }
        clock_gettime(CLOCK_MONOTONIC, &end);
        diff += (end.tv_sec - start.tv_sec) * 1E9 + (end.tv_nsec - start.tv_nsec);
    }
    return NULL;
}

int main(int argc, char* argv[]) {

    if(argc < 3) {
        printf("Usage: %s <destination_ip> <flow_dist_file> [duration=10secs] [sleep_avg=0ns] [sleep_std=0ns]\n", argv[0]);
        exit(1);
    }

    destination = argv[1];

    unsigned short fid = 1;
    experimentDurationSec = 10;
    sleepDurationAvgNs = 0;
    sleepDurationStdNs = 0;
    numFlowsPerWorker = NUMFLOWS / MAXCONN;

    if(argc > 3) experimentDurationSec = atol(argv[3]);
    if(argc > 4) sleepDurationAvgNs = atol(argv[4]);
    if(argc > 5) sleepDurationStdNs = atol(argv[5]);

    flowSizeBytesList = getDistFromFile(argv[2]);

    int* programOffset = (int*) malloc(1 * sizeof(int));
    memset(datagram, 0, BUFLEN);
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
        printf("Read %d instructions from sender file.\n", count);
    }

    if(*programOffset > MTU) {
        printf("Program too large to send over network.\n");
        exit(1);
    } else {
        programLength = *programOffset;
    }

    programOffset = (int*) malloc(1 * sizeof(int));
    memset(tailer, 0, BUFLEN);
    tailer[0] = 1;
    tailer[1] = 0;
    tailer[2] = 0;
    tailer[3] = (fid & 0xFF00) >> 8;
    tailer[4] = fid & 0xFF;
    tailer[5] = 0;
    tailer[6] = 0;
    tailer[7] = 0;
    tailer[8] = 0;
    tailer[9] = 0;
    tailer[10] = 0;
    tailer[11] = 0;
    *programOffset = 12;

    fptr = fopen("gc_program.txt", "r");
    if(fptr != NULL) {
        unsigned char opcode, gotoLabel;
        unsigned short arg;
        int count = 0;
        char buf[100];
        while( fgets(buf, 100, fptr) ) {
            opcode = (unsigned char) atoi(getField(strdup(buf), 1));
            arg = (unsigned short) atoi(getField(strdup(buf), 2));
            gotoLabel = (unsigned char) atoi(getField(strdup(buf), 3));
            addInstruction(tailer, programOffset, opcode, arg, gotoLabel);
            count++;
        }
        printf("Read %d instructions from gc file.\n", count);
    }

    numInitiatedFlows = 0;
    numDroppedFlows = 0;
    numDatagramsSent = 0;
    numBytesSent = 0;

    setup();

    pthread_t receiver[MAXCONN], sender[MAXCONN];

    for(int i = 0; i < MAXCONN; i++) {
        pthread_create(&receiver[i], NULL, nackReceiver, (void*) &cfg[i]);
        usleep(100);
    }

    printf("All listeners started. Running experiment for %d flows...\n", NUMFLOWS);

    wait = true;
    for(int i = 0; i < MAXCONN; i++) pthread_create(&sender[i], NULL, flowSender, (void*) &cfg[i]);
    
    wait = false;
    if(pthread_mutex_init(&lock, NULL) != 0) { 
        printf("mutex init failed\n"); 
        exit(1);
    }

    for(int i = 0; i < MAXCONN; i++) pthread_join(sender[i], NULL);
    usleep(1E6);
    for(int i = 0; i < MAXCONN; i++) pthread_cancel(receiver[i]);
    pthread_mutex_destroy(&lock); 

    printf("STATS: %ld flows initiated, %ld flows dropped, %ld datagrams sent, %llu bytes sent.\n", numInitiatedFlows, numDroppedFlows, numDatagramsSent, numBytesSent);

    return 0;
}
