#ifndef ACTIVEP4_H
#define ACTIVEP4_H

#define TRUE            1
#define MAXINSTRSET     256
#define MAXARGS         10
#define MAXPROGLEN      50
#define MAXPROGSIZE     512
#define MAXFILESIZE     1024
#define BUFLEN          128
#define MNEMONIC_MAXLEN 50
#define ACTIVEP4SIG     0x12345678
#define AP4_INSTR_LEN   2
#define AP4_DATA_LEN    4
#define MAX_MEMACCESS   8
#define TGT_MAX_STAGES  32

#define AP4FLAGMASK_OPT_ARGS        0x8000
#define AP4FLAGMASK_OPT_DATA        0x4000
#define AP4FLAGMASK_FLAG_EOE        0x0100
#define AP4FLAGMASK_FLAG_MARKED     0x0800
#define AP4FLAGMASK_FLAG_REMAPPED   0x0040
#define AP4FLAGMASK_FLAG_ACK        0x0200
#define AP4FLAGMASK_FLAG_INITIATED  0x0400
#define AP4FLAGMASK_FLAG_REQALLOC   0x0010
#define AP4FLAGMASK_FLAG_GETALLOC   0x0020
#define AP4FLAGMASK_FLAG_ALLOCATED  0x0008

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>
#include <ctype.h>

typedef struct {
    uint32_t    SIG;
    uint16_t    flags;
    uint16_t    fid;
    uint16_t    seq;
} __attribute__((packed)) activep4_ih;

typedef struct {
    uint32_t    data[AP4_DATA_LEN];
} __attribute__((packed)) activep4_data_t;

typedef struct {
    uint8_t     flags;
    uint8_t     opcode;
} __attribute__((packed)) activep4_instr;

typedef struct {
    uint32_t    bulk_data_0;
    uint32_t    bulk_data_1;
    uint32_t    bulk_data_2;
    uint32_t    bulk_data_3;
    uint32_t    bulk_data_4;
    uint32_t    bulk_data_5;
    uint32_t    bulk_data_6;
    uint32_t    bulk_data_7;
    uint32_t    bulk_data_8;
    uint32_t    bulk_data_9;
    uint32_t    bulk_data_10;
    uint32_t    bulk_data_11;
    uint32_t    bulk_data_12;
    uint32_t    bulk_data_13;
    uint32_t    bulk_data_14;
    uint32_t    bulk_data_15;
    uint32_t    bulk_data_16;
    uint32_t    bulk_data_17;
} __attribute__((packed)) activep4_bulk_data_t;

typedef struct {
    uint16_t    proglen;
    uint8_t     iglim;
    uint8_t     mem[MAX_MEMACCESS];
    uint8_t     dem[MAX_MEMACCESS];
} __attribute__((packed)) activep4_malloc_req_t;

typedef struct {
    uint16_t    start;
    uint16_t    end;
} __attribute__((packed)) activep4_malloc_block_t;

typedef struct {
    char        argname[20];
    int         idx;
    int         didx;
    int         value_idx;
} activep4_arg;

typedef struct {
    char        argname[20];
    uint32_t    argval;
} activep4_argval;

typedef struct {
    int         stageIdx[TGT_MAX_STAGES];
    int         numStages;
    uint16_t    memStart[TGT_MAX_STAGES];
    uint16_t    memEnd[TGT_MAX_STAGES];
    int         memSize[TGT_MAX_STAGES];
} activep4_malloc_t;

typedef struct {
    activep4_instr  ap4_prog[MAXPROGLEN];
    activep4_arg    ap4_args[MAXARGS];
    int             num_args;
    uint8_t         args_mapped;
    int             ap4_len;
    uint16_t        fid;
    uint16_t        addr_mask;
    uint16_t        addr_offset;
} activep4_t;

typedef struct {
    char    mnemonic[MNEMONIC_MAXLEN];
    char    action[MNEMONIC_MAXLEN];
    int     options;
} opcode_action_map_t;

typedef struct {
    opcode_action_map_t map[MAXINSTRSET];
    int                 num_instr;
} pnemonic_opcode_t;

static inline int pnemonic_to_opcode(pnemonic_opcode_t* instr_set, char* pnemonic) {
    int i;
    for(i = 0; i < instr_set->num_instr; i++) {
        if(strcmp(instr_set->map[i].mnemonic, pnemonic) == 0) return i;
    }
    return -1;
}

static inline void read_opcode_action_map(char* filename, pnemonic_opcode_t* instr_set) {
    int i = 0, tokidx;
    char buf[BUFLEN];
    const char* tok;
    FILE* fp = fopen(filename, "r");
    if(fp == NULL) {
        perror("fopen");
        return;
    }
    while(fgets(buf, BUFLEN, fp) != NULL) {
        tokidx = 0;
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(isspace(tok[0])) continue;
            if(tokidx == 0) strcpy(instr_set->map[i].mnemonic, tok);
            else if(tokidx == 1) strcpy(instr_set->map[i].action, tok);
            else instr_set->map[i].options = atoi(tok);
            tokidx++;
        }
        i++;
    }
    fclose(fp);
    instr_set->num_instr = i;
}

static inline void print_active_program_bytes(char* buf, int buf_size) {
    int i, instr_len = sizeof(activep4_instr);
    for(i = 0; i < buf_size; i++) {
        if(i % instr_len == 0) printf("\n");
        printf("%x ", buf[i]);
    }
    printf("\n");
}

static inline int insert_active_initial_header(char* buf, uint16_t fid, uint16_t flags) {
    activep4_ih* ap4ih = (activep4_ih*)buf;
    ap4ih->SIG = htonl(ACTIVEP4SIG);
    ap4ih->fid = htons(fid);
    ap4ih->flags = htons(flags);
    return sizeof(activep4_ih);
}

static inline int insert_active_program(char* buf, activep4_t* ap4, activep4_argval* args, int numargs) {
    int offset = 0, i, j;
    int ap4_buf_size = ap4->ap4_len * sizeof(activep4_instr);
    char* bufptr = buf;
    activep4_instr* prog = ap4->ap4_prog;
    activep4_ih* ih;
    activep4_instr* instr;
    activep4_data_t* data;
    int numinstr = ap4->ap4_len;
    ih = (activep4_ih*)buf;
    offset += insert_active_initial_header(buf, ap4->fid, 0);
    bufptr += offset;
    // insert arguments
    if(ap4->args_mapped == 0) {
        for(i = 0; i < ap4->num_args; i++) {
            for(j = 0; j < numargs; j++) {
                if(strcmp(args[j].argname, ap4->ap4_args[i].argname) == 0) {
                    ap4->ap4_args[i].value_idx = j;
                }
            }
        }
        ap4->args_mapped = 1;
    }
    memset(bufptr, 0, sizeof(activep4_data_t));
    data = (activep4_data_t*)bufptr;
    for(i = 0; i < ap4->num_args; i++) {
        data->data[ap4->ap4_args[i].didx] = htonl(args[ap4->ap4_args[i].value_idx].argval);
    }
    if(ap4->num_args > 0) {
        bufptr += sizeof(activep4_data_t);
        offset += sizeof(activep4_data_t);
        ih->flags = htons(ntohs(ih->flags) | AP4FLAGMASK_OPT_ARGS);
    }
    // insert active program
    memcpy(bufptr, (char*)ap4->ap4_prog, ap4_buf_size);
    offset += ap4_buf_size;
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
        prog[i].flags = fbuf[j];
        prog[i].opcode = fbuf[j + 1];
        #ifdef DEBUG
        printf("%d,%d\n", prog[i].flags, prog[i].opcode);
        #endif
        i++;
        j += AP4_INSTR_LEN;
    }
    ap4->ap4_len = i;
    return i;
}

static inline int read_active_args(activep4_t* ap4, char* arg_file) {
    FILE* fp = fopen(arg_file, "r");
    char buf[50];
    const char* tok;
    char argname[50];
    int i, argidx, dataidx, j, num_args = 0;
    while( fgets(buf, 50, fp) > 0 ) {
        for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, ",\n"), i++) {
            if(i == 0) strcpy(argname, tok);
            else if(i == 1) argidx = atoi(tok);
            else dataidx = atoi(tok);
        }
        ap4->ap4_args[num_args].idx = argidx;
        ap4->ap4_args[num_args].didx = dataidx;
        strcpy(ap4->ap4_args[num_args].argname, argname);
        printf("[ARG] %s %d %d\n", ap4->ap4_args[num_args].argname, ap4->ap4_args[num_args].idx,  ap4->ap4_args[num_args].didx);
        num_args++;
    }
    ap4->num_args = num_args;
    ap4->args_mapped = 0;
    fclose(fp);
    #ifdef DEBUG
    printf("%d active program arguments read.\n", ap4->num_args);
    #endif
    return ap4->num_args;
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

static inline void add_instruction(activep4_t* program, pnemonic_opcode_t* instr_set, char* instr) {
    int opcode = pnemonic_to_opcode(instr_set, instr);
    if(opcode >= 0) {
        program->ap4_prog[program->ap4_len].flags = 0;
        program->ap4_prog[program->ap4_len].opcode = opcode;
        program->ap4_len++;
    } else printf("Instruction Unknown!");
}

static inline activep4_t* construct_memsync_program(int fid, int stageId, pnemonic_opcode_t* instr_set, activep4_t* cache) {
    if(stageId > TGT_MAX_STAGES || stageId == 0) return NULL;
    if(cache[stageId].fid > 0) return &cache[stageId];
    int rts_inserted = 0, i = 0;
    add_instruction(&cache[stageId], instr_set, "MAR_LOAD_DATA_0"); i++;
    while(i < TGT_MAX_STAGES - 1) {
        if(i >= stageId) {
            add_instruction(&cache[stageId], instr_set, "MEM_READ"); i++;
            add_instruction(&cache[stageId], instr_set, "DATA_1_LOAD_MBR"); i++;
            break;
        } else if(rts_inserted == 0) {
            add_instruction(&cache[stageId], instr_set, "RTS"); i++;
            rts_inserted = 1;
        } else {
            add_instruction(&cache[stageId], instr_set, "NOP"); i++;
        }
    }
    if(rts_inserted == 0) {
        add_instruction(&cache[stageId], instr_set, "RTS");
        i++;
    }
    add_instruction(&cache[stageId], instr_set, "RETURN"); i++;
    add_instruction(&cache[stageId], instr_set, "EOF"); i++;
    cache[stageId].ap4_len = i;
    cache[stageId].fid = fid;
    return &cache[stageId];
}

static inline void construct_dummy_program(activep4_t* program, pnemonic_opcode_t* instr_set) {
    add_instruction(program, instr_set, "RTS");
    add_instruction(program, instr_set, "RETURN");
    add_instruction(program, instr_set, "EOF"); 
}

#endif