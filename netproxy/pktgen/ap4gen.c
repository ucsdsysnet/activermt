#include <pthread.h>
#include <time.h>

#include "../activep4_pktgen.h"

#define NUM_STAGES  20
#define MAX_DATA    65536

typedef struct {
    uint16_t    data[MAX_DATA];
    uint8_t     valid[MAX_DATA];
    int         mem_start;
    int         mem_end;
} memory_stage_t;

typedef struct {
    memory_stage_t  sync_data[NUM_STAGES];
    uint8_t         valid_stages[NUM_STAGES];
    uint16_t        fid;
    struct timespec sync_time;
} memory_t;

void init_memory_sync(memory_t* mem) {
    int i, j;
    for(i = 0; i < NUM_STAGES; i++) {
        mem->valid_stages[i] = 0;
        mem->sync_data[i].mem_start = 0;
        mem->sync_data[i].mem_end = 0;
        for(j = 0; j < MAX_DATA; j++) {
            mem->sync_data[i].valid[j] = 0;
            mem->sync_data[i].data[j] = 0;
        }
    }
    mem->fid = 0;
}

typedef struct {
    char            eth_iface[100];
    active_queue_t* queue;
    char            ipv4_srcaddr[100];
} rxtx_config_t;

void *run_rxtx(void *vargp) {
    rxtx_config_t* config = (rxtx_config_t*)vargp;
    active_rx_tx(config->eth_iface, config->queue, config->ipv4_srcaddr);
}

memory_t coredump;

void on_active_pkt_recv(struct ethhdr* eth, struct iphdr* iph, activep4_ih* ap4ih, activep4_data_t* ap4data) {
    if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_EOE) == 0) return;
    uint16_t index, stageId, value, fid;
    fid = ntohs(ap4ih->fid);
    index = ntohl(ap4data->data[0]);
    stageId = ntohl(ap4data->data[2]);
    value = ntohl(ap4data->data[1]);
    if(coredump.fid == fid 
        && coredump.valid_stages[stageId] > 0 
        && index >= coredump.sync_data[stageId].mem_start 
        && index <= coredump.sync_data[stageId].mem_end
    ) {
        coredump.sync_data[stageId].data[index] = value;
        coredump.sync_data[stageId].valid[index] = 1;
    }
    #ifdef DEBUG
    printf("[FID %d] sync packet (flags=%x) M%d[%d]=%d\n", fid, ntohs(ap4ih->flags), stageId, index, value);
    #endif
}

void send_memsync_pkt(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache, char* ipv4dst, unsigned char* hwaddr, uint16_t index, int stageId, int fid) {

    uint16_t flags = 0x8000;

    activep4_t* program;
    active_program_t txprog;

    program = construct_memsync_program(fid, stageId, instr_set, cache);

    txprog.ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog.ap4ih.fid = htons(fid);
    txprog.ap4ih.flags = htons(flags);

    txprog.ap4data.data[0] = htonl(index);
    txprog.ap4data.data[1] = 0;
    txprog.ap4data.data[2] = htonl(stageId);
    txprog.ap4data.data[3] = 0;

    memcpy((char*)&txprog.ap4code, (char*)&program->ap4_prog, sizeof(activep4_instr) * MAXPROGLEN);
    txprog.codelen = program->ap4_len;

    txprog.ipv4_dstaddr = ipv4dst;
    txprog.eth_dstaddr = hwaddr;

    enqueue_program(queue, &txprog);
}

void memsync(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache, char* ipv4dst, unsigned char* hwaddr) {
    int i, j, synced = 0;
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns = 0;
    printf("Initiating memory sync for FID %d ... \n", coredump.fid);
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        while(synced == 0) {
            synced = 1;
            for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
                if(coredump.sync_data[i].valid[j] == 0) {
                    synced = 0;
                    send_memsync_pkt(instr_set, queue, cache, ipv4dst, hwaddr, j, i, coredump.fid);
                }
            }
            usleep(1000000);
        }
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
            perror("clock_gettime");
            exit(1);
        }
        printf("[FID %d] Memory sync complete for stage %d\n", coredump.fid, i);
    }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    coredump.sync_time.tv_sec = ts_now.tv_sec;
    coredump.sync_time.tv_nsec = ts_now.tv_nsec;
    printf("Memory sync for FID %d completed after %lu ns\n", coredump.fid, elapsed_ns);
}

int main(int argc, char** argv) {

    if(argc < 6) {
        printf("usage: %s <eth_iface> <src_ipv4_addr> <dst_eth_addr> <dst_ipv4_addr> <instr_set_path> [fid=1]\n", argv[0]);
        exit(1);
    }

    active_queue_t queue;

    init_queue(&queue);

    rxtx_config_t config;

    strcpy(config.eth_iface, argv[1]);
    strcpy(config.ipv4_srcaddr, argv[2]);
    config.queue = &queue;

    unsigned short hwaddr[ETH_ALEN];

    if(!(strlen(argv[3]) == 17 && sscanf(argv[3], "%hx:%hx:%hx:%hx:%hx:%hx", &hwaddr[0], &hwaddr[1], &hwaddr[2], &hwaddr[3], &hwaddr[4], &hwaddr[5]) == ETH_ALEN)) {
        printf("Invalid destination ethernet address.\n");
        exit(1);
    }

    int i;
    unsigned char dst_eth_addr[ETH_ALEN];

    for(i = 0; i < ETH_ALEN; i++) dst_eth_addr[i] = (unsigned char) hwaddr[i];

    pnemonic_opcode_t instr_set;

    read_opcode_action_map(argv[5], &instr_set);

    uint16_t fid = (argc > 6) ? atoi(argv[6]) : 1;

    pthread_t rxtx;

    pthread_create(&rxtx, NULL, run_rxtx, (void*)&config);

    activep4_t cache[NUM_STAGES];

    init_memory_sync(&coredump);

    int stageId = 3, index = 0;

    coredump.fid = fid;
    coredump.valid_stages[stageId] = 1;
    coredump.sync_data[stageId].mem_start = 0;
    coredump.sync_data[stageId].mem_end = 7;

    memsync(&instr_set, &queue, cache, argv[4], dst_eth_addr);

    // for(i = 0; i < 1; i++) send_memsync_pkt(&instr_set, &queue, cache, argv[4], dst_eth_addr, i, stageId, fid);

    pthread_join(rxtx, NULL);

    return 0;
}