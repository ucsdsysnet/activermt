#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if.h>
#include <linux/if_tun.h>

#define TRUE        1
#define BUFSIZE     16384
#define IPADDRSIZE  16
#define TUNOFFSET   4
#define INSTRLEN    4
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

static inline int insert_active_program(char* buf, uint16_t fid, activep4_instr* prog, int numinstr) {
    int offset = 0, i;
    char* bufptr = buf;
    activep4_instr* instr;
    activep4_ih* ih = (activep4_ih*) bufptr;
    ih->SIG = htonl(ACTIVEP4SIG);
    ih->fid = htons(fid);
    offset += sizeof(activep4_ih);
    bufptr += offset;
    for(i = 0; i < numinstr; i++) {
        instr = (activep4_instr*) bufptr;
        instr->flags = prog[i].flags;
        instr->opcode = prog[i].opcode;
        instr->arg = prog[i].arg;
        offset += INSTRLEN;
    }
    return offset;
}

static inline int read_active_program(activep4_instr* prog, char* prog_file) {
    FILE* fp = fopen(prog_file, "rb");
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
    return i;
}

int main(int argc, char** argv) {

    if(argc < 3) {
        printf("usage: %s <remote_addr> <active_program> [fid=1]\n", argv[0]);
        exit(1);
    }

    struct sockaddr_in sin;

    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr(argv[1]);

    activep4_ih*    ap4_ih;
    activep4_instr  ap4_prog[MAXPROGLEN];
    
    int ap4_len = read_active_program(ap4_prog, argv[2]);

    int fid = (argc > 3) ? atoi(argv[3]) : 1;
    
    char dev[IFNAMSIZ];

    strcpy(dev, "tun0");
    
    int tunfd = allocate_tun(dev, IFF_TUN);

    if(tunfd < 0) {
        perror("Unable to get TUN interface.");
        exit(1);
    }

    int conn = socket(PF_INET, SOCK_RAW, IPPROTO_RAW);

    char* pptr;

    struct iphdr* iph;
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
            ap4_offset = insert_active_program(sendbuf, fid, ap4_prog, ap4_len);
            pptr = sendbuf + ap4_offset;
            iph = (struct iphdr*) (recvbuf + TUNOFFSET);
            memcpy(pptr, recvbuf + TUNOFFSET, ntohs(iph->tot_len));
            if( sendto(conn, sendbuf, ntohs(iph->tot_len) + ap4_offset, 0, (struct sockaddr*)&sin, sizeof(sin)) < 0 )
                perror("Unable to tunnel packet");
            inet_ntop(AF_INET, &iph->daddr, ipaddr, IPADDRSIZE);
            printf("%d bytes read from packet to %s with IP length %d\n", read_bytes, ipaddr, ntohs(iph->tot_len));
        }
    }

    return 0;
}