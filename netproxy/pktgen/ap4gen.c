#include <pthread.h>

#include "../activep4_pktgen.h"

#define NUM_STAGES  20

typedef struct {
    char            eth_iface[100];
    active_queue_t* queue;
    char            ipv4_srcaddr[100];
} rxtx_config_t;

void *run_rxtx(void *vargp) {
    rxtx_config_t* config = (rxtx_config_t*)vargp;
    active_rx_tx(config->eth_iface, config->queue, config->ipv4_srcaddr);
}

void on_active_pkt_recv(struct ethhdr* eth, struct iphdr* iph, activep4_ih* ap4ih, activep4_data_t* ap4data) {}

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

    int stageId = 3, index = 0;

    for(i = 0; i < 10; i++)
        send_memsync_pkt(&instr_set, &queue, cache, argv[4], dst_eth_addr, i, stageId, fid);

    pthread_join(rxtx, NULL);

    return 0;
}