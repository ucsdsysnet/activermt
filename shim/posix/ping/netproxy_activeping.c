#include <string.h>

#include "../../../include/c/common/activep4_tunnel.h"

#define MAXFILENAME     128

activep4_t      ap4;

int active_filter_tcp_tx(struct iphdr* iph, struct tcphdr* tcph, char* buf) { return 0; }
void active_filter_tcp_rx(struct iphdr* iph, struct tcphdr* tcph, activep4_ih* ap4ih) {}

int active_filter_udp_tx(struct iphdr* iph, struct udphdr* udph, char* buf) {

    int offset = 0, numargs;

    activep4_argval args[] = {
        {"ARG", 1}
    };
    numargs = 1;
    offset = insert_active_program(buf, &ap4, args, numargs);

    return offset; 
}

void active_filter_udp_rx(struct iphdr* iph, struct udphdr* udph, activep4_ih* ap4ih) {}

int main(int argc, char** argv) {

    if(argc < 5) {
        printf("usage: %s <tun_iface> <eth_iface> <dst_eth_addr> <active_program_dir> [fid=1]\n", argv[0]);
        exit(1);
    }

    char ap4_bytecode_file[MAXFILENAME], ap4_args_file[MAXFILENAME];

    sprintf(ap4_bytecode_file, "%s/ap4ping.apo", argv[4]);
    sprintf(ap4_args_file, "%s/ap4ping.args.csv", argv[4]);

    read_active_program(&ap4, ap4_bytecode_file);
    read_active_args(&ap4, ap4_args_file);

    ap4.fid = (argc > 5) ? atoi(argv[5]) : 1;

    printf("running active tunnel...\n");

    run_tunnel(argv[1], argv[2], argv[3]);

    return 0;
}