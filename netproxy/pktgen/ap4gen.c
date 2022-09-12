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

void send_memsync_pkt(pnemonic_opcode_t* instr_set, active_queue_t* queue, activep4_t* cache, char* ipv4dst, unsigned short* hwaddr, uint16_t index, int stageId, int fid) {

    uint16_t flags = 0x0000;

    activep4_t* program;
    activep4_ih ap4ih;
    activep4_data_t data;
    active_program_t txprog;

    program = construct_memsync_program(fid, stageId, instr_set, cache);

    ap4ih.SIG = htonl(ACTIVEP4SIG);
    ap4ih.fid = htons(fid);
    ap4ih.flags = htons(flags);

    data.data[0] = index;
    data.data[2] = stageId;

    txprog.ap4ih = &ap4ih;
    txprog.ap4code = program->ap4_prog;
    txprog.codelen = program->ap4_len;
    txprog.ap4data = &data;
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

    pnemonic_opcode_t instr_set;

    read_opcode_action_map(argv[5], &instr_set);

    uint16_t fid = (argc > 6) ? atoi(argv[6]) : 1;

    pthread_t rxtx;

    pthread_create(&rxtx, NULL, run_rxtx, (void*)&config);

    activep4_t cache[NUM_STAGES];

    int stageId = 3, index = 0;
    
    send_memsync_pkt(&instr_set, &queue, cache, argv[4], hwaddr, index, stageId, fid);

    pthread_join(rxtx, NULL);

    return 0;
}