#define _GNU_SOURCE

#include <pthread.h>
#include <time.h>

#include "../../headers/activep4_pktgen.h"

//#define DEBUG

#define MODE_ALLOC  0
#define MODE_SYNC   1
#define ASYNC_TX    0
#define NUM_STAGES  20
#define RETRY_ITVL  10000
#define SEND_ITVL   100
#define MAX_RETRIES 100000
#define MAX_SYNC_R  100
#define NUM_REPEATS 100

#define CMS_MAGIC       0x87654321
#define CMS_MAXKEYS     65536
#define CMS_TOPK        8192
#define CMS_MAXSAMPLES  10000
#define CMS_EXPDURSEC   60

static inline void prettify_duration(unsigned long ts, char* buf) {
    if(ts < 1E3) sprintf(buf, "%lu ns", ts);
    else if(ts < 1E6) sprintf(buf, "%lf us", ts / 1E3);
    else if(ts < 1E9) sprintf(buf, "%lf ms", ts / 1E6);
    else sprintf(buf, "%lf s", ts / 1E9);
}

typedef struct {
    char            eth_iface[100];
    active_queue_t* queue;
    char            ipv4_srcaddr[100];
    char            ipv4_dstaddr[100];
    unsigned char   eth_dstmac[ETH_ALEN];
} rxtx_config_t;

typedef struct {
    uint64_t    duration_allocation_request;
    uint64_t    duration_allocation_fetch;
    uint64_t    duration_memory_sync;
} experiment_t;

void *run_rxtx(void *vargp) {
    rxtx_config_t* config = (rxtx_config_t*)vargp;
    active_rx_tx(config->queue, config->ipv4_srcaddr, config->ipv4_dstaddr, config->eth_dstmac);
}

static inline void mutate_active_program(activep4_t* ap4, active_program_t* program, memory_t* memcfg, int NOP_OPCODE) {
    
    int access_idx_allocated[NUM_STAGES], i, j, block_start, block_end, offset;

    memset(&access_idx_allocated, 0, NUM_STAGES * sizeof(int));

    j = 0;
    for(i = 0; i < NUM_STAGES; i++) {
        if(memcfg->valid_stages[i] == 1) access_idx_allocated[j++] = i;
    }

    if(j != ap4->num_accesses) {
        printf("Invalid number of stages allocated!\n");
        return;
    }

    program->codelen = ap4->ap4_len + access_idx_allocated[ap4->num_accesses - 1] - ap4->access_idx[ap4->num_accesses - 1];
    memset(&program->ap4code, 0, program->codelen * sizeof(activep4_instr));

    for(i = 0; i < program->codelen; i++) program->ap4code[i].opcode = NOP_OPCODE;

    block_end = ap4->ap4_len - 1;
    while(j > 0) {
        j--;
        block_start = ap4->access_idx[j];
        offset = access_idx_allocated[j] - ap4->access_idx[j];
        for(i = block_end; i >= block_start; i--) 
            program->ap4code[i + offset] = ap4->ap4_prog[i];
        block_end = block_start - 1;
    }

    for(i = 0; i < ap4->access_idx[0]; i++)
        program->ap4code[i] = ap4->ap4_prog[i];
}

// pthread_mutex_t lock;

memory_t coredump;
int isAllocated, isRemapped, allocationInitiated, isSyncing;
int syncInit;

typedef struct {
    uint32_t    key;
    uint32_t    value;
} cms_obj_t;

cms_obj_t cms_counts[CMS_MAXKEYS], cms_gt[CMS_MAXKEYS];
uint64_t num_hits, num_misses;

void on_active_pkt_recv(struct ethhdr* eth, struct iphdr* iph, activep4_ih* ap4ih, activep4_data_t* ap4data, activep4_malloc_res_t* ap4alloc) {

    uint16_t fid;

    fid = ntohs(ap4ih->fid);

    if(coredump.fid != fid) return;

    uint32_t magic = CMS_MAGIC;

    // printf("FLAGS 0x%x\n", ntohs(ap4ih->flags));

    if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_REQALLOC) > 0) {
        allocationInitiated = 1;
    } else if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_ALLOCATED) > 0) {
        // Allocation response packet.
        printf("(ALLOCATION) <FID %d> ", fid);
        int i;
        for(i = 0; i < NUM_STAGES; i++) {
            coredump.sync_data[i].mem_start = ntohs(ap4alloc->mem_range[i].start);
            coredump.sync_data[i].mem_end = ntohs(ap4alloc->mem_range[i].end);
            if((coredump.sync_data[i].mem_end - coredump.sync_data[i].mem_start) > 0) {
                coredump.valid_stages[i] = 1;
                printf("[S%d: %d-%d] ", i, coredump.sync_data[i].mem_start, coredump.sync_data[i].mem_end);
            }
        }
        printf("\n");
        isAllocated = 1;
        isRemapped = 0;
        coredump.invalid = 0;
    } 
    if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_REMAPPED) > 0) {
        // Remap packet.
        isRemapped = 1;
        coredump.invalid = 1;
        //printf("Remap packet 0x%x\n", ntohs(ap4ih->flags));
    } 
    if((ntohs(ap4ih->flags) & AP4FLAGMASK_FLAG_EOE) > 0) {
        // Memsync packet / active program packet.
        uint32_t data_0, data_1, data_2, data_3;
        if((ntohs(ap4ih->flags) & AP4FLAGMASK_OPT_ARGS) > 0) {
            data_0 = ntohl(ap4data->data[0]);
            data_1 = ntohl(ap4data->data[1]);
            data_2 = ntohl(ap4data->data[2]);
            data_3 = ntohl(ap4data->data[3]);
            //printf("DATA: %u,%u,%u,%u\n", data_0, data_1, data_2, data_3);
        }
        if(isSyncing == 1 || syncInit == 1) {
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
        } else if(data_3 == magic) {
            // CMS.
            //cms_counts[data_0].value = data_1;
            //printf("Key=%u, Count=%u\n", data_0, data_1);
            // CACHE.
            //printf("CACHEDATA: %u,%u,%u,%u\n", data_0, data_1, data_2, data_3);
            if(data_0 == data_2) num_hits++;
            else num_misses++;
        }
    }
}

int send_active_pkt(activep4_t* program, pnemonic_opcode_t* instr_set, active_queue_t* queue) {
    
    uint16_t flags = AP4FLAGMASK_OPT_ARGS;

    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

    txprog.ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog.ap4ih.fid = htons(program->fid);
    txprog.ap4ih.flags = htons(flags);

    memcpy(&txprog.ap4code, (char*)&program->ap4_prog, sizeof(activep4_instr) * MAXPROGLEN);
    txprog.codelen = program->ap4_len;

    if(ASYNC_TX == 1) {
        enqueue_program(queue, &txprog);
        return 0;
    } else return active_tx(&txprog);
}

void send_memsync_pkt(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache, uint16_t index, int stageId, int fid) {

    uint16_t flags = AP4FLAGMASK_OPT_ARGS;

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

void send_memset_pkt(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache, uint16_t index, int stageId, int fid) {

    uint16_t flags = AP4FLAGMASK_OPT_ARGS;

    activep4_t* program;
    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

    program = construct_memset_program(fid, stageId, instr_set, cache);

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

void send_memsync_init(active_queue_t* queue, int fid) {

    uint16_t flags = AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_INITIATED;
    
    active_program_t txprog;

    memset((char*)&txprog, 0, sizeof(active_program_t));

    txprog.ap4ih.SIG = htonl(ACTIVEP4SIG);
    txprog.ap4ih.fid = htons(fid);
    txprog.ap4ih.flags = htons(flags);

    txprog.codelen = 0;

    if(ASYNC_TX == 1) enqueue_program(queue, &txprog);
    else active_tx(&txprog);
}

void send_memsync_ack(active_queue_t* queue, int fid) {

    uint16_t flags = AP4FLAGMASK_FLAG_REMAPPED | AP4FLAGMASK_FLAG_ACK;
    
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
    if(syncInit == 1) return;
    syncInit = 1;
    int i, j, synced, sync_batches, num_pkts, remaining;
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns = 0;
    //#ifdef DEBUG
    printf("Initiating memory sync for FID %d ... \n", coredump.fid);
    //#endif
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
            coredump.sync_data[i].valid[j] = 0;
        }
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        synced = 0;
        sync_batches = 0;
        while(synced == 0 && sync_batches < MAX_SYNC_R) {
            synced = 1;
            remaining = 0;
            for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
                if(coredump.sync_data[i].valid[j] == 0) {
                    synced = 0;
                    remaining++;
                    send_memsync_pkt(instr_set, queue, cache, j, i, coredump.fid);
                }
            }
            //#ifdef DEBUG
            printf("%d packets remaining ... \n", remaining);
            if(synced == 1) {
                num_pkts = coredump.sync_data[i].mem_end - coredump.sync_data[i].mem_start + 1;
                printf("[FID %d] Memory sync (with %d packets) complete for stage %d in %d batches\n", coredump.fid, num_pkts, i, sync_batches);
            }
            //#endif
            sync_batches++;
            //usleep(RETRY_ITVL);
        }
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    coredump.sync_time.tv_sec = ts_now.tv_sec;
    coredump.sync_time.tv_nsec = ts_now.tv_nsec;
    coredump.sync_duration = elapsed_ns;
    //#ifdef DEBUG
    char duration[100];
    prettify_duration(elapsed_ns, duration);
    printf("Memory sync for FID %d completed after %s\n", coredump.fid, duration);
    //#endif
    syncInit = 0;
}

void memerase(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache) {
    if(syncInit == 1) return;
    syncInit = 1;
    int i, j, synced, sync_batches, num_pkts, remaining;
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns = 0;
    //#ifdef DEBUG
    printf("Initiating memory erase for FID %d ... \n", coredump.fid);
    //#endif
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
            coredump.sync_data[i].valid[j] = 0;
        }
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        synced = 0;
        sync_batches = 0;
        while(synced == 0 && sync_batches < MAX_SYNC_R) {
            synced = 1;
            remaining = 0;
            for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
                if(coredump.sync_data[i].valid[j] == 0) {
                    synced = 0;
                    remaining++;
                    send_memset_pkt(instr_set, queue, cache, j, i, coredump.fid);
                    break;
                }
            }
            break;
            //#ifdef DEBUG
            printf("%d packets remaining ... \n", remaining);
            if(synced == 1) {
                num_pkts = coredump.sync_data[i].mem_end - coredump.sync_data[i].mem_start + 1;
                printf("[FID %d] Memory erase (with %d packets) complete for stage %d in %d batches\n", coredump.fid, num_pkts, i, sync_batches);
            }
            //#endif
            sync_batches++;
            //usleep(RETRY_ITVL);
        }
        break;
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    coredump.sync_time.tv_sec = ts_now.tv_sec;
    coredump.sync_time.tv_nsec = ts_now.tv_nsec;
    coredump.sync_duration = elapsed_ns;
    //#ifdef DEBUG
    char duration[100];
    prettify_duration(elapsed_ns, duration);
    printf("Memory erase for FID %d completed after %s\n", coredump.fid, duration);
    //#endif
    syncInit = 0;
}

void memsync_testmode(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache) {
    int i, j, ret;
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;
    active_program_t recvprogram;
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    for(i = 0; i < NUM_STAGES; i++) {
        if(coredump.valid_stages[i] == 0) continue;
        for(j = coredump.sync_data[i].mem_start; j <= coredump.sync_data[i].mem_end; j++) {
            if(coredump.sync_data[i].valid[j] == 0) {
                #ifdef DEBUG
                printf("sending memsync packet [stage %d][index %d] ... ", i, j); 
                #endif
                fflush(stdout);
                memset(&recvprogram, 0, sizeof(active_program_t));
                send_memsync_pkt(instr_set, queue, cache, j, i, coredump.fid);
                ret = active_rx(&recvprogram);
                #ifdef DEBUG
                if(ret == 0) printf("OK [flags 0x%x].\n", ntohs(recvprogram.ap4ih.flags));
                else j--; // retry.
                #else
                if(ret != 0) j--;
                #endif
            }
        }
    }
    if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
    coredump.sync_time.tv_sec = ts_now.tv_sec;
    coredump.sync_time.tv_nsec = ts_now.tv_nsec;
    coredump.sync_duration = elapsed_ns;
}

void init_memory_allocation(int fid, active_queue_t* queue, int num_accesses, int* access_idx, int* demand, int proglen, int iglim) {
    int retries = 0;
    while(allocationInitiated == 0 && retries < MAX_RETRIES) {
        send_malloc_request(queue, fid, num_accesses, access_idx, demand, proglen, iglim);
        usleep(RETRY_ITVL);
        retries++;
    }
}

void get_memory_allocation(int fid, active_queue_t* queue) {
    int retries = 0;
    isAllocated = 0;
    while(isAllocated == 0 && retries < MAX_RETRIES) {
        send_malloc_fetch(queue, fid);
        usleep(RETRY_ITVL);
        retries++;
    }
}

void active_tx_loop(activep4_t* program, pnemonic_opcode_t* instr_set, active_queue_t* queue) {
    int result;
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns, bytes_sent = 0, packets_sent = 0, datarate_pps = 0, datarate_bps = 0;
    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
        perror("clock_gettime");
        exit(1);
    }
    while(TRUE) {
        
        result = send_active_pkt(program, instr_set, queue);
        if(result > 0) {
            bytes_sent += result;
            packets_sent++;
        }

        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) { perror("clock_gettime"); exit(1); }
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        if(elapsed_ns >= 1E9) {
            memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));
            datarate_bps = bytes_sent;
            datarate_pps = packets_sent;
            bytes_sent = 0;
            packets_sent = 0;
            printf("[STATS] data rate: %lu pps %lu Bps\n", datarate_pps, datarate_bps);
        }
    }
}

void write_experiment_results(char* filename, experiment_t* results, int num_datapoints) {
    
    FILE *fp = fopen(filename, "w");

    int i;
    for(i = 0; i < num_datapoints; i++) {
        fprintf(fp, "%lu,%lu,%lu\n", results[i].duration_allocation_request, results[i].duration_allocation_fetch, results[i].duration_memory_sync);
    }

    fclose(fp);

    printf("%d results written to %s\n", num_datapoints, filename);
}

int cmpfunc (const void * a, const void * b) {
   return ( ((cms_obj_t*)a)->value - ((cms_obj_t*)b)->value );
}

int main(int argc, char** argv) {

    if(argc < 7) {
        printf("usage: %s <eth_iface> <src_ipv4_addr> <dst_eth_addr> <dst_ipv4_addr> <instr_set_path> <mode=0(alloc)|1(sync)> [fid=1]\n", argv[0]);
        exit(1);
    }

    pthread_t timer_thread;
    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }
    cpu_set_t cpuset_timer;
    CPU_ZERO(&cpuset_timer);
    CPU_SET(40, &cpuset_timer);
    if(pthread_setaffinity_np(timer_thread, sizeof(cpu_set_t), &cpuset_timer) != 0) {
        perror("pthread_setaffinity()");
    }

    experiment_t experiment[NUM_REPEATS];

    memset(&experiment, 0, NUM_REPEATS * sizeof(experiment_t));

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

    activep4_t cache[NUM_STAGES], erase_cache[NUM_STAGES];

    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    /////////////////////////////////////////////////

    char* active_bytecode_cache = "../../apps/cache/active/cacheread.apo";
    char* active_bytecode_cms = "../../apps/cms/active/cms_basic.apo";

    activep4_t program_cms;
    memset(&program_cms, 0, sizeof(activep4_t));

    read_active_program(&program_cms, active_bytecode_cache);
    //read_active_program(&program_cms, active_bytecode_cms);
    printf("AP4 length: %d instructions.\n", program_cms.ap4_len);
    //print_active_program_bytes((char*)&program_cms.ap4_prog, program_cms.ap4_len * 2);

    /*program_cms.num_accesses = 4;
    program_cms.access_idx[0] = 4;
    program_cms.access_idx[1] = 7;
    program_cms.access_idx[2] = 9;
    program_cms.access_idx[3] = 11;
    program_cms.demand[0] = 1;
    program_cms.demand[1] = 1;
    program_cms.demand[2] = 1;
    program_cms.demand[3] = 1;
    program_cms.proglen = 14;
    program_cms.iglim = 0;*/

    program_cms.num_accesses = 3;
    program_cms.access_idx[0] = 4;
    program_cms.access_idx[1] = 7;
    program_cms.access_idx[2] = 9;
    program_cms.demand[0] = 1;
    program_cms.demand[1] = 1;
    program_cms.demand[2] = 1;
    program_cms.proglen = 12;
    program_cms.iglim = 0;

    /* ========================================== */

    /*activep4_t active_program;

    construct_dummy_program(&active_program, &instr_set);
    active_program.fid = fid;

    active_tx_loop(&active_program, &instr_set, &queue);
    exit(0);*/

    pthread_t rxtx;

    memset(&coredump, 0, sizeof(memory_t));

    pthread_create(&rxtx, NULL, run_rxtx, (void*)&config);

    /*cpu_set_t cpuset;
    int s;

    CPU_ZERO(&cpuset);
        for (i = 40; i < 60; i += 2)
            CPU_SET(i, &cpuset);
    
    s = pthread_setaffinity_np(rxtx, sizeof(cpu_set_t), &cpuset);
    if(s != 0) perror("pthread_setaffinity");*/

    coredump.fid = fid;
    for(i = 0; i < program_cms.num_accesses; i++) {
        coredump.valid_stages[program_cms.access_idx[i]] = 1;
    }

    /////////////////////////////////////////////////////////////////

    isSyncing = 0;
    isAllocated = 0;
    allocationInitiated = 0;
    isRemapped = 0;

    /*printf("initiating alloc ... \n");
    init_memory_allocation(fid, &queue, program_cms.num_accesses, program_cms.access_idx, program_cms.demand, program_cms.proglen, program_cms.iglim);
    printf("fetching alloc ... \n");
    get_memory_allocation(fid, &queue);
    printf("OK.\n");*/

    active_program_t variant_cms;
    memset(&variant_cms, 0, sizeof(active_program_t));

    mutate_active_program(&program_cms, &variant_cms, &coredump, pnemonic_to_opcode(&instr_set, "NOP"));
    // print_active_program_bytes((char*)&variant_cms.ap4code, variant_cms.codelen * 2);

    variant_cms.ap4ih.SIG = htonl(ACTIVEP4SIG);
    variant_cms.ap4ih.fid = htons(fid);
    variant_cms.ap4ih.flags = htons(AP4FLAGMASK_OPT_ARGS);

    uint32_t key = 1;

    variant_cms.ap4data.data[3] = htonl(CMS_MAGIC);

    double prob = 0.5, accuracy[CMS_MAXSAMPLES];
    uint64_t sample_ts[CMS_MAXSAMPLES];
    int sampleIdx = 0;
    uint64_t expDuration = CMS_EXPDURSEC * 1E9;
    uint64_t plim = RAND_MAX * prob;
    uint64_t epoch_duration_ns = 1E9, total_hits_misses;
    uint32_t other, found, num_positives = 0, flag_remapped = 0;

    memset(cms_counts, 0, CMS_MAXKEYS * sizeof(cms_obj_t));
    memset(cms_gt, 0, CMS_MAXKEYS * sizeof(cms_obj_t));

    struct timespec ts_init;
    if( clock_gettime(CLOCK_MONOTONIC, &ts_init) < 0 ) {perror("clock_gettime");exit(1);}

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime");exit(1);}

    num_hits = 0;
    num_misses = 0;

    while(TRUE) {
        
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

        //coredump.invalid == 1 || 
        if(isRemapped == 1) {
            flag_remapped = 1;
            //send_malloc_fetch(&queue, fid);
            printf("Getting updated allocation ... \n");
            //sample_ts[sampleIdx] = ts_now.tv_sec;
            //accuracy[sampleIdx++] = -2;
            get_memory_allocation(fid, &queue);
            isRemapped = 0;
        } 
        //else {
            if(elapsed_ns >= epoch_duration_ns) {
                memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));

                /*qsort(cms_gt, CMS_MAXKEYS, sizeof(cms_obj_t), cmpfunc);
                qsort(cms_counts, CMS_MAXKEYS, sizeof(cms_obj_t), cmpfunc);

                num_positives = 0;
                for(key = 0; key < CMS_TOPK; key++) {
                    found = 0;
                    for(other = 0; other < CMS_TOPK; other++) {
                        if(cms_counts[other].key == cms_gt[key].key) {
                            found = 1;
                            break;
                        }
                    }
                    if(found == 1) num_positives++;
                }

                //for(key = 0; key < CMS_MAXKEYS; key++) {printf("[C] %u=%u, [GT] %u=%u\n", cms_counts[key].key, cms_counts[key].value, cms_gt[key].key, cms_gt[key].value);}

                sample_ts[sampleIdx] = ts_now.tv_sec;
                accuracy[sampleIdx++] = (double)num_positives / CMS_TOPK;

                //printf("%u / %u top k keys correctly detected.\n", num_positives, CMS_TOPK);

                memset(cms_counts, 0, CMS_MAXKEYS * sizeof(cms_obj_t));
                memset(cms_gt, 0, CMS_MAXKEYS * sizeof(cms_obj_t));*/

                total_hits_misses = num_hits + num_misses;
                sample_ts[sampleIdx] = ts_now.tv_sec;
                if(isRemapped == 1) {
                    accuracy[sampleIdx++] = -2;
                } else {
                    if(total_hits_misses > 0)
                        accuracy[sampleIdx++] = 
                        //total_hits_misses;
                        (double)num_hits / total_hits_misses;
                    else accuracy[sampleIdx++] = -3;
                }
                //printf("epoch %lu hits %lu misses\n", num_hits, num_misses);
                num_hits = 0;
                num_misses = 0;
            }

            //key = (key + 1) % CMS_MAXKEYS;
            //key = (key + 1) % 10;
            key = rand() % CMS_MAXKEYS;
            //key = 32769;
            memset(&variant_cms.ap4data, 0, sizeof(activep4_data_t));
            variant_cms.ap4data.data[3] = htonl(CMS_MAGIC);
            variant_cms.ap4data.data[2] = htonl(key);
            variant_cms.ap4data.data[1] = htonl(0);
            active_tx(&variant_cms);

            /*for(key = 0; key < CMS_MAXKEYS; key++) {
                if(rand() > plim) continue;
                cms_gt[key].value++;
                cms_gt[key].key = key;
                cms_counts[key].key = key;
                variant_cms.ap4data.data[0] = htonl(key);
                variant_cms.ap4data.data[1] = 0;
                active_tx(&variant_cms);
            }*/
        //}

        elapsed_ns = (ts_now.tv_sec - ts_init.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_init.tv_nsec);
        if(elapsed_ns >= expDuration) break;

        //usleep(SEND_ITVL);
    }

    char cms_samples_filename[100];
    sprintf(cms_samples_filename, "cache_samples_fid_%d.csv", fid);
    FILE *fp = fopen(cms_samples_filename, "w");
    for(key = 0; key < sampleIdx; key++) {
        fprintf(fp, "%lu,%lf\n", sample_ts[key], accuracy[key]);
    }
    fclose(fp);

    //sleep(2);

    //syncInit = 0;
    //memerase(&instr_set, &queue, erase_cache);

    exit(0);

    /* ====================== TMP ALLOC ===================== */

    //if(fid == 3) {
    //printf("Experiment controller.\n");

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

    active_program_t program;

    int preallocated = 0, k;

    printf("Initiating malloc measurements ... \n");

    for(k = 0; k < NUM_REPEATS; k++) {

        printf("Experiment %d starting ...\n", k);

        memset(&program, 0, sizeof(active_program_t));
        send_malloc_request(&queue, FID_RST, num_accesses, access_idx, demand, proglen, iglim);
        // active_rx(&program);

        sleep(5);

        printf("Resuming iter %d ... \n", k);

        for(i = 0; i < 3; i++) {

            fid = i + 1;
            coredump.fid = fid;

            preallocated = 0;
            isAllocated = 0;
            allocationInitiated = 0;

            if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {
                perror("clock_gettime");
                exit(1);
            }

            /*memset(&program, 0, sizeof(active_program_t));
            send_malloc_fetch(&queue, fid);
            active_rx(&program);

            if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
                perror("clock_gettime");
                exit(1);
            }
            elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

            if(fid == 3) experiment[k].duration_allocation_fetch = elapsed_ns;

            if((ntohs(program.ap4ih.flags) & AP4FLAGMASK_FLAG_ALLOCATED) > 0) {
                preallocated = 1;
            } else {
                memset(&program, 0, sizeof(active_program_t));
                send_malloc_request(&queue, fid, num_accesses, access_idx, demand, proglen, iglim);
                active_rx(&program);
                while(TRUE) {
                    memset(&program, 0, sizeof(active_program_t));
                    send_malloc_fetch(&queue, fid);
                    active_rx(&program);
                    if((ntohs(program.ap4ih.flags) & AP4FLAGMASK_FLAG_ALLOCATED) > 0) break;
                    usleep(10);
                }
            }*/

            //send_malloc_request(&queue, fid, num_accesses, access_idx, demand, proglen, iglim);
            printf("initiating alloc ... \n");
            init_memory_allocation(fid, &queue, num_accesses, access_idx, demand, proglen, iglim);
            printf("fetching alloc ... \n");
            get_memory_allocation(fid, &queue);
            printf("OK.\n");

            if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {
                perror("clock_gettime");
                exit(1);
            }
            elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);

            if(fid == 3) experiment[k].duration_allocation_request = elapsed_ns;

            if(preallocated == 1) printf("Already allocated FID %d.\n", fid);

            char duration[100];
            prettify_duration(elapsed_ns, duration);
            printf("ELAPSED: %s\n", duration);

            usleep(100000);
        }

        printf("Experiment %d complete.\n", k);
    }

    char* results_filename = "results.csv";

    write_experiment_results(results_filename, experiment, NUM_REPEATS);

    //}
    

    //exit(0);

    /* ================= TMP ALLOC ================ */

    //if(fid != 3) {
    //printf("Remap Listener.\n");

    /* Memory allocation */

    /*int num_accesses, access_idx[NUM_STAGES], demand[NUM_STAGES], proglen, iglim;

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
    printf("Allocation time: %s\n", duration);*/

    int send_interval_us = 100000;
    activep4_t dummy_program;

    construct_dummy_program(&dummy_program, &instr_set);
    dummy_program.fid = fid;
    
    isRemapped = 0;

    while(TRUE) {
        if(isRemapped == 1) {
            syncInit = 0;
            //printf("Initiating memory snapshot ... \n");
            send_memsync_init(&queue, fid);
            //usleep(100000);
            memsync(&instr_set, &queue, cache);
            send_memsync_ack(&queue, fid);
            isRemapped = 0;
        } else {
            send_active_pkt(&dummy_program, &instr_set, &queue);
        }
        usleep(send_interval_us);
    }

    // TODO: remove.

    /*num_accesses = 1;
    access_idx[0] = 3;
    coredump.fid = fid;
    for(i = 0; i < num_accesses; i++) {
        coredump.valid_stages[access_idx[i]] = 1;
        coredump.sync_data[access_idx[i]].mem_start = 0;
        coredump.sync_data[access_idx[i]].mem_end = 0xFFFF;
    }
    
    if(mode == MODE_SYNC) {
        printf("SYNC mode.\n");

        activep4_t cache[NUM_STAGES];

        activep4_t dummy_program;

        construct_dummy_program(&dummy_program, &instr_set);
        dummy_program.fid = fid;

        // TODO: dummy pkt stream, remap listener, alloc update.

        int k;
        for(k = 0; k < NUM_REPEATS; k++) {
            memset(&coredump, 0, sizeof(memory_t));
            num_accesses = 1;
            access_idx[0] = 3;
            coredump.fid = fid;
            for(i = 0; i < num_accesses; i++) {
                coredump.valid_stages[access_idx[i]] = 1;
                coredump.sync_data[access_idx[i]].mem_start = 0;
                coredump.sync_data[access_idx[i]].mem_end = 0xFFFF;
            }
            //memsync(&instr_set, &queue, cache);
            memsync_testmode(&instr_set, &queue, cache);
            experiment[k].duration_memory_sync = coredump.sync_duration;
        }
    }*/

    //}

    pthread_join(rxtx, NULL);
    pthread_join(timer_thread, NULL);

    return 0;
}