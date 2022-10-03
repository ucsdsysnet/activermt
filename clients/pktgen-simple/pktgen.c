#define _GNU_SOURCE
#include "../../headers/activep4_netutils.h"
#include "../../headers/stats.h"

#define MEMPOOL_SIZE    1024
#define NUM_TX_THREADS  4

stats_t stats;

void rx_handler(net_headers_t* hdrs) {
    /*pthread_mutex_lock(&lock);
    stats.count++;
    pthread_mutex_unlock(&lock);*/
}

void* tx_burst_sender(void* argp) {

    port_config_t* cfg = (port_config_t*)argp;

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

    while(TRUE) {
        // send burst of pkts.
        tx_burst(cfg, mempool, MEMPOOL_SIZE);
        pthread_mutex_lock(&lock);
        stats.count += MEMPOOL_SIZE;
        pthread_mutex_unlock(&lock);
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
        printf("Usage: %s <iface> <ipv4_dstaddr>\n", argv[0]);
        exit(1);
    }

    char* iface = argv[1];
    char* ipv4_dstaddr = argv[2];

    port_config_t cfg;
    memset(&cfg, 0, sizeof(port_config_t));
    if(port_init(&cfg, iface, inet_addr(ipv4_dstaddr)) < 0) {
        exit(1);
    }

    cfg.rx_handler = rx_handler;

    memset(&stats, 0, sizeof(stats_t));

    pthread_t timer_thread;
    if( pthread_create(&timer_thread, NULL, monitor_stats, (void*)&stats) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    pthread_t rx_thread;
    if( pthread_create(&rx_thread, NULL, rx_loop, (void*)&cfg) < 0 ) {
        perror("pthread_create()");
        exit(1);
    }

    set_cpu_affinity(40, 40, &timer_thread);
    set_cpu_affinity(42, 42, &rx_thread);

    pthread_t tx_thread[NUM_TX_THREADS];
    for(int i = 0; i < NUM_TX_THREADS; i++) {
        if( pthread_create(&tx_thread[i], NULL, tx_burst_sender, (void*)&cfg) < 0 ) {
            perror("pthread_create()");
            exit(1);
        }
        set_cpu_affinity(44 + 2*i, 44 + 2*i, &tx_thread[i]);
    }

    pthread_join(timer_thread, NULL);
    pthread_join(rx_thread, NULL);

    for(int i = 0; i < NUM_TX_THREADS; i++)
        pthread_join(tx_thread[i], NULL);

    return 0;
}