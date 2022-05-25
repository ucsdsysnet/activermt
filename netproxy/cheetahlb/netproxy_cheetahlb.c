#include <string.h>
#include <stdlib.h>

#include "../activep4_tunnel.h"

//#define EXPERIMENTAL

#define MAXCONN         65536
#define MAXFILENAME     128

typedef struct {
    uint8_t         active;
    uint16_t        cookie;
    uint64_t        fin_ts;
    inet_5tuple_t   conn;
    uint8_t         insert_cookie;
} cheetah_lb_t;

cheetah_lb_t    app[MAXCONN];
activep4_t      ap4_conn, ap4_data;

int active_filter_udp_tx(struct iphdr* iph, struct udphdr* udph, char* buf) { return 0; }
void active_filter_udp_rx(struct iphdr* iph, struct udphdr* udph, activep4_ih* ap4ih) {}

int active_filter_tcp_tx(struct iphdr* iph, struct tcphdr* tcph, char* buf) {
    int numargs, offset = 0;
    uint16_t vip_addr, conn_id, cookie;
    #ifdef EXPERIMENTAL
    if(rand() % 2 == 0) app[conn_id].insert_cookie = 0;
    #endif
    inet_5tuple_t conn = {
        iph->saddr,
        iph->daddr,
        iph->protocol,
        tcph->source,
        tcph->dest
    };
    conn_id = cksum_5tuple(&conn);
    if(tcph->syn == 1 && tcph->ack == 0) {
        // SYN packet
        #ifdef DEBUG
        printf("TCP connection initiation.\n");
        #endif
        vip_addr = (uint16_t) (ntohl(iph->daddr) & 0x0000FF00) >> 8;
        // TODO apply mask and offset
        activep4_argval args[] = {
            {"BUCKET_SIZE", 0},
            {"VIP_ADDR", vip_addr}
        };
        numargs = 2;
        offset = insert_active_program(buf, &ap4_conn, args, numargs);
        app[conn_id].active = 1;
        app[conn_id].cookie = 0;
        app[conn_id].insert_cookie = 1;
        memcpy(&app[conn_id].conn, &conn, sizeof(inet_5tuple_t));
    } else {
        // other TCP segments
        #ifdef EXPERIMENTAL
        cookie = (app[conn_id].insert_cookie == 1) ? app[conn_id].cookie : 0;
        #else
        cookie = app[conn_id].cookie;
        #endif
        activep4_argval args[] = {
            {"COOKIE", cookie}
        };
        numargs = 1;
        offset = insert_active_program(buf, &ap4_data, args, numargs);
        ((activep4_ih*)buf)->acc = htons(app[conn_id].cookie);
        #ifdef DEBUG
        printf("Cookie: %d\n", app[conn_id].cookie);
        #endif
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
    }
}

int main(int argc, char** argv) {

    if(argc < 4) {
        printf("usage: %s <tun_iface> <eth_iface> <active_program_dir> [fid=1]\n", argv[0]);
        exit(1);
    }

    char ap4_conn_bytecode_file[MAXFILENAME], ap4_conn_args_file[MAXFILENAME];
    char ap4_data_bytecode_file[MAXFILENAME], ap4_data_args_file[MAXFILENAME];

    sprintf(ap4_conn_bytecode_file, "%s/cheetahlb-syn.apo", argv[3]);
    sprintf(ap4_conn_args_file, "%s/cheetahlb-syn.args.csv", argv[3]);
    sprintf(ap4_data_bytecode_file, "%s/cheetahlb-default.apo", argv[3]);
    sprintf(ap4_data_args_file, "%s/cheetahlb-default.args.csv", argv[3]);

    read_active_program(&ap4_conn, ap4_conn_bytecode_file);
    read_active_args(&ap4_conn, ap4_conn_args_file);
    read_active_program(&ap4_data, ap4_data_bytecode_file);
    read_active_args(&ap4_data, ap4_data_args_file);

    ap4_conn.fid = (argc > 4) ? atoi(argv[4]) : 1;
    ap4_data.fid = ap4_conn.fid;

    printf("running active tunnel...\n");

    run_tunnel(argv[1], argv[2]);

    return 0;
}