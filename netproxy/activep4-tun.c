#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_tun.h>

#define DEBUG       1

#define TRUE        1
#define BUFSIZE     16384
#define IPADDRSIZE  16
#define TUNOFFSET   4
#define MAXARGS     10
#define MAXPROGLEN  50
#define MAXFILESIZE 1024
#define ACTIVEP4SIG 0x12345678

typedef struct {
    uint32_t    SIG;
    uint16_t    flags;
    uint16_t    fid;
    uint16_t    seq;
    uint16_t    acc;
    uint16_t    acc2;
    uint16_t    data;
    uint16_t    data2;
    uint16_t    res;
} activep4_ih;

typedef struct {
    uint8_t     flags;
    uint8_t     opcode;
    uint16_t    arg;
} activep4_instr;

typedef struct {
    char        argname[20];
    uint8_t     valid;
    int         idx;
} activep4_arg;

typedef struct {
    char        argname[20];
    uint16_t    argval;
} activep4_argval;

typedef struct {
    activep4_instr  ap4_prog[MAXPROGLEN];
    activep4_arg    ap4_argmap[MAXARGS];
    int             ap4_len;
    int             num_args;
    uint16_t        fid;
} activep4_t;

int allocate_tun(char* dev, int flags) {
    struct ifreq ifr;
    int fd, err;
    char* tundev = "/dev/net/tun";

    if( (fd = open(tundev, O_RDWR)) < 0 ) return fd;

    memset(&ifr, 0, sizeof(ifr));

    ifr.ifr_flags = flags;

    if(*dev) strncpy(ifr.ifr_name, dev, IFNAMSIZ);

    if( (err = ioctl(fd, TUNSETIFF, (void*)&ifr)) < 0 ) {
        close(fd);
        return err;
    }

    strcpy(dev, ifr.ifr_name);

    return fd;
}

static inline int insert_active_program(char* buf, activep4_t* ap4, activep4_argval* args, int numargs) {
    int offset = 0, i;
    char* bufptr = buf;
    uint16_t fid = ap4->fid;
    activep4_instr* prog = ap4->ap4_prog;
    activep4_arg* argmap = ap4->ap4_argmap;
    activep4_instr* instr;
    int numinstr = ap4->ap4_len;
    activep4_ih* ih = (activep4_ih*) bufptr;
    ih->SIG = htonl(ACTIVEP4SIG);
    ih->fid = htons(fid);
    offset += sizeof(activep4_ih);
    bufptr += offset;
    int j;
    for(i = 0; i < MAXARGS; i++) {
        if(argmap[i].valid == 1) {
            argmap[i].idx = -1;
            for(j = 0; j < numargs; j++) {
                if(strcmp(args[j].argname, argmap[i].argname) == 0)
                    argmap[i].idx = j;
            }
        }
    }
    for(i = 0; i < numinstr; i++) {
        instr = (activep4_instr*) bufptr;
        instr->flags = prog[i].flags;
        instr->opcode = prog[i].opcode;
        instr->arg = (argmap[i].valid == 1) ? htons(args[argmap[i].idx].argval) : 0;
        #ifdef DEBUG
        printf("AP4: %d,%d,%d\n", instr->flags, instr->opcode, instr->arg);
        #endif
        offset += sizeof(activep4_instr);
        bufptr += sizeof(activep4_instr);
    }
    return offset;
}

static inline int read_active_program(activep4_t* ap4, char* prog_file) {
    FILE* fp = fopen(prog_file, "rb");
    activep4_instr* prog = ap4->ap4_prog;
    fseek(fp, 0, SEEK_END);
    int ap4_size = ftell(fp);
    rewind(fp);
    char fbuf[MAXFILESIZE];
    fread(fbuf, ap4_size, 1, fp);
    fclose(fp);
    int i = 0, j = 0;
    uint16_t arg;
    while(i < MAXPROGLEN && j < ap4_size) {
        arg = fbuf[j + 2] << 8 + fbuf[j + 3];
        prog[i].flags = fbuf[j];
        prog[i].opcode = fbuf[j + 1];
        prog[i].arg = htons(arg);
        i++;
        j += 4;
    }
    ap4->ap4_len = i;
    return i;
}

static inline int read_active_args(activep4_t* ap4, char* arg_file) {
    FILE* fp = fopen(arg_file, "r");
    activep4_arg* argmap = ap4->ap4_argmap;
    char buf[50];
    const char* tok;
    char argname[50];
    int i, argidx;
    for(i = 0; i < MAXARGS; i++) argmap[i].valid = 0;
    while( fgets(buf, 50, fp) > 0 ) {
        for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, "\n"), i++) {
            if(i == 0) strcpy(argname, tok);
            else argidx = atoi(tok);
        }
        strcpy(argmap[argidx].argname, argname);
        argmap[argidx].valid = 1;
        #ifdef DEBUG
        printf("Active argument %s at index %d\n", argmap[argidx].argname, argidx);
        #endif
    }
    ap4->num_args = argidx;
    return argidx;
}

static inline int active_filter_tcp(struct iphdr* iph, struct tcphdr* tcph, char* buf, activep4_t* ap4) {
    int numargs = 2, offset = 0;
    uint16_t vip_addr;
    if(tcph->syn == 1 && tcph->ack == 0) {
        // connection initiator
        #ifdef DEBUG
        printf("TCP connection initiation.\n");
        #endif
        vip_addr = (uint16_t) (ntohl(iph->daddr) & 0x0000FFFF);
        // TODO apply mask and offset
        activep4_argval args[] = {
            {"BUCKET_SIZE", 4},
            {"VIP_ADDR", vip_addr}
        };
        offset = insert_active_program(buf, ap4, args, numargs);
    } else {
        // regular segment
    }
    return offset;
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("usage: %s <remote_addr> <active_program> [active_args] [fid=1]\n", argv[0]);
        exit(1);
    }

    struct sockaddr_in sin;

    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr(argv[1]);

    activep4_t      ap4;
    
    int ap4_len = read_active_program(&ap4, argv[2]);
    int num_args = (argc > 3) ? read_active_args(&ap4, argv[3]) : 0;

    ap4.fid = (argc > 4) ? atoi(argv[4]) : 1;
    
    char dev[IFNAMSIZ];

    strcpy(dev, "tun0");
    
    int tunfd = allocate_tun(dev, IFF_TUN);

    if(tunfd < 0) {
        perror("Unable to get TUN interface.");
        exit(1);
    }

    int conn = socket(PF_INET, SOCK_RAW, IPPROTO_RAW);

    char* pptr;

    struct iphdr*   iph;
    struct tcphdr*  tcph;
    char ipaddr[IPADDRSIZE];

    int read_bytes, ap4_offset;
    char recvbuf[BUFSIZE], sendbuf[BUFSIZE];
    while(TRUE) {
        read_bytes = read(tunfd, recvbuf, sizeof(recvbuf));
        if(read_bytes < 0) {
            perror("Unable to read from TUN interface");
            close(tunfd);
            exit(1);
        } else {
            memset(sendbuf, 0, BUFSIZE);
            iph = (struct iphdr*) (recvbuf + TUNOFFSET);
            pptr = sendbuf;
            if(iph->protocol == IPPROTO_TCP) {
                tcph = (struct tcphdr*) (recvbuf + TUNOFFSET + sizeof(struct iphdr));
                ap4_offset = active_filter_tcp(iph, tcph, sendbuf, &ap4);
                pptr += ap4_offset;
            }
            memcpy(pptr, recvbuf + TUNOFFSET, ntohs(iph->tot_len));
            if( sendto(conn, sendbuf, ntohs(iph->tot_len) + ap4_offset, 0, (struct sockaddr*)&sin, sizeof(sin)) < 0 )
                perror("Unable to tunnel packet");
            #ifdef DEBUG
            inet_ntop(AF_INET, &iph->daddr, ipaddr, IPADDRSIZE);
            printf("%d bytes read from packet to %s with IP length %d\n", read_bytes, ipaddr, ntohs(iph->tot_len));
            #endif
        }
    }

    return 0;
}