#ifndef ACTIVEP4_H
#define ACTIVEP4_H

#define TRUE            1
#define MAXARGS         10
#define MAXPROGLEN      50
#define MAXFILESIZE     1024
#define ACTIVEP4SIG     0x12345678
#define AP4FLAGS_DONE   0x0100

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>

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

static inline int insert_active_initial_header(char* buf, uint16_t fid, uint16_t flags) {
    activep4_ih* ap4ih = (activep4_ih*)buf;
    ap4ih->SIG = htonl(ACTIVEP4SIG);
    ap4ih->fid = htons(fid);
    ap4ih->flags = htons(flags);
    return sizeof(activep4_ih);
}

static inline int insert_active_program(char* buf, activep4_t* ap4, activep4_argval* args, int numargs) {
    int offset = 0, i;
    char* bufptr = buf;
    activep4_instr* prog = ap4->ap4_prog;
    activep4_arg* argmap = ap4->ap4_argmap;
    activep4_instr* instr;
    int numinstr = ap4->ap4_len;
    offset += insert_active_initial_header(buf, ap4->fid, 0);
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
    #ifdef DEBUG
    printf("[Active Program]\n");
    #endif
    while(i < MAXPROGLEN && j < ap4_size) {
        arg = fbuf[j + 2] << 8 + fbuf[j + 3];
        prog[i].flags = fbuf[j];
        prog[i].opcode = fbuf[j + 1];
        prog[i].arg = htons(arg);
        #ifdef DEBUG
        printf("%d,%d,%d\n", prog[i].flags, prog[i].opcode, prog[i].arg);
        #endif
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
    fclose(fp);
    ap4->num_args = argidx;
    return argidx;
}

static inline int get_active_eof(char* buf) {
    int eof = 0;
    activep4_instr* instr = (activep4_instr*) buf;
    while(instr->opcode != 0) {
        eof = eof + sizeof(activep4_instr);
        instr++;
    }
    eof = eof + sizeof(activep4_instr);
    return eof;
}

static inline int is_activep4(char* buf) {
    uint32_t* signature = (uint32_t*) buf;
    return (ntohl(*signature) == ACTIVEP4SIG);
}

#endif