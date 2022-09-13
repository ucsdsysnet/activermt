#include <pthread.h>
#include <time.h>

#include "../activep4_pktgen.h"

#define MODE_ALLOC  0
#define MODE_SYNC   1
#define ASYNC_TX    0
#define NUM_STAGES  20
#define MAX_DATA    65536
#define MAX_FIDX    256
#define RETRY_ITVL  1000
#define MAX_RETRIES 10000

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
    char            ipv4_dstaddr[100];
    unsigned char   eth_dstmac[ETH_ALEN];
} rxtx_config_t;

void *run_rxtx(void *vargp) {
    rxtx_config_t* config = (rxtx_config_t*)vargp;
    active_rx_tx(config->queue, config->ipv4_srcaddr, config->ipv4_dstaddr, config->eth_dstmac);
}

// pthread_mutex_t lock;

memory_t coredump;
int isAllocated;

void on_active_pkt_recv(struct ethhdr* eth, struct iphdr* iph, activep4_ih* ap4ih, activep4_data_t* ap4data, activep4_malloc_res_t* ap4alloc) {
    
    // printf("FLAGS 0x%x\n", ntohs(ap4ih->flags));

    uint16_t fid;

    fid = ntohs(ap4ih->fid);

    if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_ALLOCATED) > 0) {
        // Allocation response packet.
        if(coredump.fid != fid) return;
        int i;
        for(i = 0; i < NUM_STAGES; i++) {
            coredump.sync_data[i].mem_start = ntohs(ap4alloc->mem_range[i].start);
            coredump.sync_data[i].mem_end = ntohs(ap4alloc->mem_range[i].end);
            if((coredump.sync_data[i].mem_end - coredump.sync_data[i].mem_start) > 0)
                coredump.valid_stages[i] = 1;
        }
        isAllocated = 1;
    } else if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_EOE) > 0) {
        // Memsync packet.
        uint16_t index, stageId, value;
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
}

void send_active_pkt(activep4_t* program, pnemonic_opcode_t* instr_set, active_queue_t* queue) {
    
    uint16_t flags = 0x0000;

    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

    txprog.ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog.ap4ih.fid = htons(program->fid);
    txprog.ap4ih.flags = htons(flags);

    memcpy((char*)&txprog.ap4code, (char*)&program->ap4_prog, sizeof(activep4_instr) * MAXPROGLEN);
    txprog.codelen = program->ap4_len;

    if(ASYNC_TX == 1) enqueue_program(queue, &txprog);
    else active_tx(&txprog);
}

void send_memsync_pkt(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache, uint16_t index, int stageId, int fid) {

    uint16_t flags = 0x8000;

    activep4_t* program;
    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

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

    if(ASYNC_TX == 1) enqueue_program(queue, &txprog);
    else active_tx(&txprog);
}

void send_malloc_request(active_queue_t* queue, int fid, int num_accesses, int* access_idx, int* demand, int proglen, int iglim) {

    uint16_t flags = AP4FLAGMASK_FLAG_REQALLOC;
    
    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

    txprog.ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog.ap4ih.fid = htons(fid);
    txprog.ap4ih.flags = htons(flags);

    txprog.codelen = 0;

    int i;

    txprog.ap4malloc.proglen = htons(proglen);
    txprog.ap4malloc.iglim = iglim;
    for(i = 0; i < num_accesses; i++) {
        txprog.ap4malloc.mem[i] = access_idx[i];
        txprog.ap4malloc.dem[i] = demand[i];
    }

    if(ASYNC_TX == 1) enqueue_program(queue, &txprog);
    else active_tx(&txprog);
}

void send_malloc_fetch(active_queue_t* queue, int fid) {

    uint16_t flags = AP4FLAGMASK_FLAG_GETALLOC;
    
    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

    txprog.ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog.ap4ih.fid = htons(fid);
    txprog.ap4ih.flags = htons(flags);

    txprog.codelen = 0;

    if(ASYNC_TX == 1) enqueue_program(queue, &txprog);
    else active_tx(&txprog);
}

void memsync(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache) {
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
                    send_memsync_pkt(instr_set, queue, cache, j, i, coredump.fid);
                }
            }
            usleep(RETRY_ITVL);
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

void get_memory_allocation(int fid, active_queue_t* queue) {
    int retries = 0;
    while(isAllocated == 0 && retries < MAX_RETRIES) {
        send_malloc_fetch(queue, fid);
        usleep(RETRY_ITVL);
        retries++;
    }
}

static inline void prettify_duration(unsigned long ts, char* buf) {
    if(ts < 1E3) sprintf(buf, "%lu ns", ts);
    else if(ts < 1E6) sprintf(buf, "%lf us", ts / 1E3);
    else if(ts < 1E9) sprintf(buf, "%lf ms", ts / 1E6);
    else sprintf(buf, "%lf s", ts / 1E9);
}

int main(int argc, char** argv) {

    if(argc < 7) {
        printf("usage: %s <eth_iface> <src_ipv4_addr> <dst_eth_addr> <dst_ipv4_addr> <instr_set_path> <mode=0(alloc)|1(sync)> [fid=1]\n", argv[0]);
        exit(1);
    }

    active_queue_t queue;

    init_queue(&queue);

    unsigned short hwaddr[ETH_ALEN];

    if(!(strlen(argv[3]) == 17 && sscanf(argv[3], "%hx:%hx:%hx:%hx:%hx:%hx", &hwaddr[0], &hwaddr[1], &hwaddr[2], &hwaddr[3], &hwaddr[4], &hwaddr[5]) == ETH_ALEN)) {
        printf("Invalid destination ethernet address.\n");
        exit(1);
    }

    int i;
    unsigned char dst_eth_addr[ETH_ALEN];

    for(i = 0; i < ETH_ALEN; i++) dst_eth_addr[i] = (unsigned char) hwaddr[i];

    rxtx_config_t config;

    strcpy(config.eth_iface, argv[1]);
    strcpy(config.ipv4_srcaddr, argv[2]);
    strcpy(config.ipv4_dstaddr, argv[4]);
    memcpy(config.eth_dstmac, dst_eth_addr, ETH_ALEN);
    config.queue = &queue;

    pnemonic_opcode_t instr_set;

    read_opcode_action_map(argv[5], &instr_set);

    int mode = atoi(argv[6]);

    uint16_t fid = (argc > 7) ? atoi(argv[7]) : 1;

    rx_tx_init(argv[1], argv[2], argv[4], dst_eth_addr);

    pthread_t rxtx;

    init_memory_sync(&coredump);

    pthread_create(&rxtx, NULL, run_rxtx, (void*)&config);

    coredump.fid = fid;

    /* Memory allocation */

    int num_accesses, access_idx[NUM_STAGES], demand[NUM_STAGES], proglen, iglim;

    num_accesses = 3;
    access_idx[0] = 3;
    access_idx[1] = 6;
    access_idx[2] = 9;
    demand[0] = 1;
    demand[1] = 1;
    demand[2] = 1;
    proglen = 12;
    iglim = 8;

    isAllocated = 0;

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    send_malloc_request(&queue, fid, num_accesses, access_idx, demand, proglen, iglim);

    get_memory_allocation(fid, &queue);

    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }

    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

    printf("ALLOCATION [FID %d]\n", fid);
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.sync_data[i].mem_end - coredump.sync_data[i].mem_start > 0)
            printf("Stage %d [%u - %u]\n", i, coredump.sync_data[i].mem_start, coredump.sync_data[i].mem_end);
    }

    char duration[100];
    prettify_duration(elapsed_ns, duration);
    printf("Allocation time: %s\n", duration);
    
    if(mode == MODE_SYNC) {
        /* Memory synchronization */

        printf("SYNC mode.\n");

        activep4_t cache[NUM_STAGES];

        activep4_t dummy_program;

        construct_dummy_program(&dummy_program, &instr_set);
        dummy_program.fid = fid;

        int send_interval_us = 10000;

        while(TRUE) {
            send_active_pkt(&dummy_program, &instr_set, &queue);
            usleep(send_interval_us);
        }

        // TODO: dummy pkt stream, remap listener, alloc update.

        //memsync(&instr_set, &queue, cache, argv[4], dst_eth_addr);

        // for(i = 0; i < 1; i++) send_memsync_pkt(&instr_set, &queue, cache, argv[4], dst_eth_addr, i, stageId, fid);
    }

    pthread_join(rxtx, NULL);

    return 0;
}