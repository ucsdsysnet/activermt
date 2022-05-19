#include "../activep4_tunnel.h"

typedef struct {
    uint8_t         active;
    uint8_t         awterm;
    uint16_t        cookie;
    inet_5tuple_t   conn;
} cheetah_lb_t;

cheetah_lb_t    app[MAXCONN];
activep4_t      ap4;

int active_filter_udp_tx(struct iphdr* iph, struct udphdr* udph, char* buf) {
    int offset = insert_active_initial_header(buf, ap4.fid, AP4FLAGS_DONE);
    return offset;
}

void active_filter_udp_rx(struct iphdr* iph, struct tcphdr* tcph, activep4_ih* ap4ih) {}

int active_filter_tcp_tx(struct iphdr* iph, struct tcphdr* tcph, char* buf) {
    int numargs = 2, offset = 0;
    uint16_t vip_addr, conn_id;
    inet_5tuple_t conn = {
        iph->saddr,
        iph->daddr,
        iph->protocol,
        tcph->source,
        tcph->dest
    };
    activep4_ih* ap4ih;
    conn_id = cksum_5tuple(&conn);
    if(tcph->syn == 1 && tcph->ack == 0) {
        // SYN packet
        #ifdef DEBUG
        printf("TCP connection initiation.\n");
        #endif
        vip_addr = (uint16_t) (ntohl(iph->daddr) & 0x0000FFFF);
        // TODO apply mask and offset
        activep4_argval args[] = {
            {"BUCKET_SIZE", 4},
            {"VIP_ADDR", vip_addr}
        };
        offset = insert_active_program(buf, &ap4, args, numargs);
        app[conn_id].active = 1;
        app[conn_id].cookie = 0;
        app[conn_id].awterm = 0;
        memcpy(&app[conn_id].conn, &conn, sizeof(inet_5tuple_t));
    } else {
        // other TCP segments
        offset = insert_active_initial_header(buf, ap4.fid, AP4FLAGS_DONE);
        ap4ih = (activep4_ih*)buf;
        ap4ih->acc = htons(app[conn_id].cookie);
    }
    if(tcph->fin == 1) {
        // FIN packet
        app[conn_id].awterm = 1;
    }
    return offset;
}

void active_filter_tcp_rx(struct iphdr* iph, struct tcphdr* tcph, activep4_ih* ap4ih) {
    inet_5tuple_t conn = {
        iph->saddr,
        iph->daddr,
        iph->protocol,
        tcph->source,
        tcph->dest
    };
    uint16_t conn_id = cksum_5tuple(&conn);
    if(tcph->syn == 1) {
        // SYN packet (either way)
        app[conn_id].active = 1;
        app[conn_id].cookie = ntohs(ap4ih->acc);
        memcpy(&app[conn_id].conn, &conn, sizeof(inet_5tuple_t));
        #ifdef DEBUG
        printf("SYN: setting (for connection %u) cookie to %u\n", conn_id, app[conn_id].cookie);
        #endif
    } else if(tcph->ack == 1 && app[conn_id].awterm == 1) {
        #ifdef DEBUG
        printf("FIN: terminating connection %u\n", conn_id);
        #endif
        app[conn_id].active = 0;
        app[conn_id].cookie = 0;
        app[conn_id].awterm = 0;
        memset(&app[conn_id].conn, 0, sizeof(inet_5tuple_t));
    }
}

int main(int argc, char** argv) {

    if(argc < 4) {
        printf("usage: %s <tun_iface> <eth_iface> <dst_eth_addr> [<active_program> [active_args]] [fid=1]\n", argv[0]);
        exit(1);
    }

    ap4.ap4_len = 0;
    
    int ap4_len = (argc > 4) ? read_active_program(&ap4, argv[4]) : 0;
    int num_args = (argc > 5) ? read_active_args(&ap4, argv[5]) : 0;

    ap4.fid = (argc > 6) ? atoi(argv[6]) : 1;

    run_tunnel(argv[1], argv[2], argv[3]);

    return 0;
}