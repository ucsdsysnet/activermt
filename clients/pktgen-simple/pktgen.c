#define _GNU_SOURCE
#include "../../headers/activep4_netutils.h"

//#define RATE_LIMITED    1
#define IO_MMAP         1
#define MAX_PPS         1000000
#define MEMPOOL_SIZE    2048
#define NUM_TX_THREADS  2
#define NUM_RX_THREADS  2

void rx_handler(net_headers_t* hdrs) {}

void* tx_burst_sender(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;

    tx_pkt_t mempool[MEMPOOL_SIZE];
    memset(mempool, 0, MEMPOOL_SIZE * sizeof(tx_pkt_t));

    struct ethhdr* eth;
    struct iphdr* iph;
    struct udphdr* udph;

    for(int i = 0; i < MEMPOOL_SIZE; i++) {

        eth = (struct ethhdr*)mempool[i].buf;
        memcpy(&eth->h_source, &cfg->dev_info.hwaddr, ETH_ALEN);
        memcpy(&eth->h_dest, &cfg->eth_dstaddr, ETH_ALEN);
        eth->h_proto = htons(ETH_P_IP);

        iph = (struct iphdr*)(mempool[i].buf + sizeof(struct ethhdr));
        iph->ihl = 5;
        iph->version = 4;
        iph->tos = 0;
        iph->tot_len = htons(sizeof(struct iphdr) + sizeof(struct udphdr));
        iph->id = htonl(0);
        iph->frag_off = 0;
        iph->ttl = 255;
        iph->protocol = IPPROTO_UDP;
        iph->check = 0;
        iph->saddr = cfg->dev_info.ipv4addr;
        iph->daddr = cfg->ipv4_dstaddr;

        udph = (struct udphdr*)(mempool[i].buf + sizeof(struct ethhdr) + sizeof(struct iphdr));
        udph->source = htons(1234);
        udph->dest = htons(5678);

        mempool[i].pktlen = sizeof(struct ethhdr) + sizeof(struct iphdr) + sizeof(struct udphdr);
    }

    #ifdef RATE_LIMITED
    struct timespec ts_start, ts_now;
    uint64_t send_itvl_ns = 0, elapsed_ns = 0, num_batches, batch_itvl_ns;
    #endif

    while(TRUE) {
        #ifdef RATE_LIMITED
        if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}
        #endif
        tx_burst(cfg, mempool, MEMPOOL_SIZE);
        #ifdef RATE_LIMITED
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        num_batches = th_cfg->tx_pps / MEMPOOL_SIZE;
        batch_itvl_ns = 1E9 / num_batches;
        send_itvl_ns = (batch_itvl_ns > elapsed_ns) ? batch_itvl_ns - elapsed_ns : 0;
        busy_wait(send_itvl_ns);
        #endif
    }
}

void* tx_mmap_sender(void* argp) {

    thread_config_t* th_cfg = (thread_config_t*)argp;
    port_config_t* cfg = th_cfg->cfg;
    
    tx_pkt_t mempool[MEMPOOL_SIZE];
    while(is_running) {
        tx_mmap_enqueue(cfg, mempool, MEMPOOL_SIZE);
    }
}

static inline void set_cpu_affinity(int core_id_start, int core_id_end, pthread_t* thread) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    for(int i = core_id_start; i <= core_id_start; i++)
        CPU_SET(i, &cpuset);
    if(pthread_setaffinity_np(*thread, sizeof(cpu_set_t), &cpuset) != 0) {
        perror("pthread_setaffinity()");
    }
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("Usage: %s <iface> <ipv4_dstaddr> [tx_rate_pps]\n", argv[0]);
        exit(1);
    }

    char* iface = argv[1];
    char* ipv4_dstaddr = argv[2];
    int tx_pps = (argc > 3) ? atoi(argv[3]) : MAX_PPS;

    tx_pps = (tx_pps < MEMPOOL_SIZE * NUM_TX_THREADS) ? MEMPOOL_SIZE * NUM_TX_THREADS : tx_pps;
    tx_pps = (tx_pps > MAX_PPS) ? MAX_PPS : tx_pps;

    is_running = 1;

    memset(&stats, 0, sizeof(stats_t));
    pthread_t timer_thread;
    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }
    set_cpu_affinity(40, 40, &timer_thread);

    port_config_t cfg;
    memset(&cfg, 0, sizeof(port_config_t));

    cfg.dev_info.iface_name = iface;
    cfg.ipv4_dstaddr = inet_addr(ipv4_dstaddr);

    int sockfd;
    if((sockfd = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL))) < 0) {
        perror("socket()");
        exit(1);
    }
    get_iface(&cfg.dev_info, cfg.dev_info.iface_name, sockfd);
    
    if(arp_resolve(cfg.ipv4_dstaddr, iface, cfg.eth_dstaddr) == 0) {
        printf("Error: IP address could not be resolved!\n");
        exit(1);
    }

    memset(&cfg.eth_dst_addr, 0, sizeof(struct sockaddr_ll));
    cfg.eth_dst_addr.sll_family = AF_PACKET;
    cfg.eth_dst_addr.sll_ifindex = cfg.dev_info.iface_index;
    cfg.eth_dst_addr.sll_protocol = htons(ETH_P_AP4);
    cfg.eth_dst_addr.sll_halen = ETH_ALEN;
    memcpy(&cfg.eth_dst_addr.sll_addr, cfg.eth_dstaddr, ETH_ALEN);

    #ifdef IO_MMAP
        //port_init_mmap(&cfg);
        setup_rx_ring(&cfg.rx_ring);
        setup_tx_ring(&cfg.tx_ring, cfg.dev_info.iface_index);
        tx_setup_buffers(&cfg);

        thread_config_t rx_cfg = {0};
        rx_cfg.cfg = &cfg;
        rx_cfg.rx_handler = rx_handler;
        pthread_t rx_thread;
        if( pthread_create(&rx_thread, NULL, rx_mmap_loop, (void*)&rx_cfg) < 0 ) {
            perror("pthread_create()");
            exit(1);
        }
        set_cpu_affinity(50, 50, &rx_thread);

        thread_config_t tx_cfg = {0};
        tx_cfg.cfg = &cfg;
        pthread_t tx_thread;
        if( pthread_create(&tx_thread, NULL, tx_mmap_loop, (void*)&tx_cfg) < 0 ) {
            perror("pthread_create()");
            exit(1);
        }
        set_cpu_affinity(52, 52, &tx_thread);

        thread_config_t tx_qcfg = {0};
        tx_qcfg.cfg = &cfg;
        pthread_t tx_qthread;
        if( pthread_create(&tx_qthread, NULL, tx_mmap_sender, (void*)&tx_qcfg) < 0 ) {
            perror("pthread_create()");
            exit(1);
        }
        set_cpu_affinity(54, 54, &tx_qthread);

        pthread_join(rx_thread, NULL);
        pthread_join(tx_thread, NULL);
        pthread_join(tx_qthread, NULL);
    #else
        if(port_init(&cfg, iface, inet_addr(ipv4_dstaddr)) < 0) {
            exit(1);
        }
        
        thread_config_t tx_cfg[NUM_TX_THREADS], rx_cfg[NUM_RX_THREADS];
        for(int i = 0; i < NUM_TX_THREADS; i++) {
            memset(&tx_cfg[i], 0, sizeof(thread_config_t));
            tx_cfg[i].thread_id = i;
            tx_cfg[i].cfg = &cfg;
            tx_cfg[i].tx_pps = tx_pps / NUM_TX_THREADS;
        }
        /*int num_blocks = cfg.pmmap.num_blocks / NUM_RX_THREADS;
        int num_frames = cfg.pmmap.frames_per_buffer * num_blocks;
        int remaining_blocks = cfg.pmmap.num_blocks * cfg.pmmap.frames_per_buffer;
        for(int i = 0; i < NUM_RX_THREADS; i++) {
            memset(&rx_cfg[i], 0, sizeof(thread_config_t));
            rx_cfg[i].thread_id = i;
            rx_cfg[i].cfg = &cfg;
            rx_cfg[i].rx_handler = rx_handler;
            rx_cfg[i].num_frames = num_frames;
            rx_cfg[i].frame_offset = i * num_frames;
            remaining_blocks -= num_frames;
        }
        rx_cfg[NUM_RX_THREADS - 1].num_frames += remaining_blocks;*/

        pthread_t rx_thread[NUM_RX_THREADS];
        for(int i = 0; i < NUM_RX_THREADS; i++) {
            if( pthread_create(&rx_thread[i], NULL, rx_mmap_loop, (void*)&rx_cfg[i]) < 0 ) {
                perror("pthread_create()");
                exit(1);
            }
            set_cpu_affinity(50 + 2*i, 50 + 2*i, &rx_thread[i]);
        }

        pthread_t tx_thread[NUM_TX_THREADS];
        for(int i = 0; i < NUM_TX_THREADS; i++) {
            if( pthread_create(&tx_thread[i], NULL, tx_burst_sender, (void*)&tx_cfg[i]) < 0 ) {
                perror("pthread_create()");
                exit(1);
            }
            set_cpu_affinity(60 + 2*i, 60 + 2*i, &tx_thread[i]);
        }

        for(int i = 0; i < NUM_RX_THREADS; i++)
            pthread_join(rx_thread[i], NULL);

        for(int i = 0; i < NUM_TX_THREADS; i++)
            pthread_join(tx_thread[i], NULL);
    #endif

    pthread_join(timer_thread, NULL);
    
    return 0;
}