#ifndef ACTIVEP4_H
#define ACTIVEP4_H

//#define DEBUG

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
#define NUM_STAGES      20
#define MAX_DATA        65536
#define MAX_FIDX        256
#define FID_RST         255

#define AP4FLAGMASK_OPT_ARGS        0x8000
#define AP4FLAGMASK_FLAG_EOE        0x0100
#define AP4FLAGMASK_FLAG_MARKED     0x0800
#define AP4FLAGMASK_FLAG_REMAPPED   0x0040
#define AP4FLAGMASK_FLAG_ACK        0x0200
#define AP4FLAGMASK_FLAG_INITIATED  0x0400
#define AP4FLAGMASK_FLAG_REQALLOC   0x0010
#define AP4FLAGMASK_FLAG_GETALLOC   0x0020
#define AP4FLAGMASK_FLAG_ALLOCATED  0x0008

#define ACTIVE_STATE_TRANSMITTING   0
#define ACTIVE_STATE_ALLOCATING     1
#define ACTIVE_STATE_INITIALIZING   2
#define ACTIVE_STATE_SNAPSHOTTING   3
#define ACTIVE_STATE_SNAPCOMPLETING 4

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>
#include <ctype.h>
#include <errno.h>
#include <arpa/inet.h>

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
    activep4_malloc_block_t mem_range[NUM_STAGES];
} __attribute__((packed)) activep4_malloc_res_t;

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
    int         stageIdx[NUM_STAGES];
    int         numStages;
    uint16_t    memStart[NUM_STAGES];
    uint16_t    memEnd[NUM_STAGES];
    int         memSize[NUM_STAGES];
} activep4_malloc_t;

typedef struct {
    uint16_t    data[MAX_DATA];
    uint8_t     valid[MAX_DATA];
    int         mem_start;
    int         mem_end;
} memory_stage_t;

typedef struct {
    uint8_t         invalid;
    memory_stage_t  sync_data[NUM_STAGES];
    uint8_t         valid_stages[NUM_STAGES];
    uint16_t        fid;
    uint16_t        version;
    uint16_t        sync_version;
    uint64_t        sync_start_time;
    uint64_t        sync_end_time;
} memory_t;

typedef struct {
    uint16_t        fid;
    activep4_instr  code[MAXPROGLEN];
    activep4_arg    args[MAXARGS];
    int             num_args;
    uint8_t         args_mapped;
    int             num_accesses;
    int             access_idx[NUM_STAGES];
    int             demand[NUM_STAGES];
    int             proglen;
    int             iglim;
} activep4_def_t;

typedef struct {
    char    mnemonic[MNEMONIC_MAXLEN];
    char    action[MNEMONIC_MAXLEN];
    int     options;
} opcode_action_map_t;

typedef struct {
    opcode_action_map_t map[MAXINSTRSET];
    int                 num_instr;
} pnemonic_opcode_t;

typedef struct {
    uint8_t             is_active;
    uint8_t             status;
    pnemonic_opcode_t*  instr_set;   
    activep4_def_t*     program;
    memory_t            allocation;
    activep4_data_t     data;
    uint32_t            ipv4_srcaddr;
} activep4_context_t;

static inline void print_active_program_bytes(char* buf, int buf_size) {
    int i, instr_len = sizeof(activep4_instr);
    for(i = 0; i < buf_size; i++) {
        if(i % instr_len == 0) printf("\n");
        printf("%x ", buf[i]);
    }
    printf("\n");
}

static inline int pnemonic_to_opcode(pnemonic_opcode_t* instr_set, char* pnemonic) {
    int i;
    for(i = 0; i < instr_set->num_instr; i++) {
        if(strcmp(instr_set->map[i].mnemonic, pnemonic) == 0) return i;
    }
    return -1;
}

static inline int read_opcode_action_map(char* filename, pnemonic_opcode_t* instr_set) {
    int i = 0, tokidx;
    char buf[BUFLEN];
    const char* tok;
    FILE* fp = fopen(filename, "r");
    if(fp == NULL) {
        perror("fopen");
        return errno;
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
    return 0;
}

static inline int read_active_program(activep4_def_t* ap4, char* prog_file) {
    FILE* fp = fopen(prog_file, "rb");
    activep4_instr* code = ap4->code;
    fseek(fp, 0, SEEK_END);
    int ap4_size = ftell(fp);
    rewind(fp);
    char fbuf[MAXFILESIZE];
    int read = fread(fbuf, ap4_size, 1, fp);
    fclose(fp);
    int i = 0, j = 0;
    uint16_t arg;
    #ifdef DEBUG
    printf("[Active Program]\n");
    #endif
    while(i < MAXPROGLEN && j < ap4_size) {
        code[i].flags = fbuf[j];
        code[i].opcode = fbuf[j + 1];
        #ifdef DEBUG
        printf("%d,%d\n", code[i].flags, code[i].opcode);
        #endif
        i++;
        j += AP4_INSTR_LEN;
    }
    ap4->proglen = i;
    return ap4->proglen;
}

static inline void read_active_memaccess(activep4_def_t* ap4, char* memidx_file) {
    FILE* fp = fopen(memidx_file, "rb");
    char buf[50];
    const char* tok;
    int memidx[NUM_STAGES], i, iglim = -1;
    if(fgets(buf, 50, fp) > 0) {
        for(i = 0, tok = strtok(buf, ","); tok && *tok; tok = strtok(NULL, ",\n"), i++) {
            memidx[i] = atoi(tok);
        }
    }
    if(fgets(buf, 50, fp) > 0) {
        iglim = atoi(buf);
    }
    fclose(fp);
    ap4->num_accesses = i;
    ap4->iglim = iglim;
    for(i = 0; i < ap4->num_accesses; i++) {
        ap4->access_idx[i] = memidx[i];
        ap4->demand[i] = 1; // TODO read from config.
    }
}

static inline int read_active_args(activep4_def_t* ap4, char* arg_file) {
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
        ap4->args[num_args].idx = argidx;
        ap4->args[num_args].didx = dataidx;
        strcpy(ap4->args[num_args].argname, argname);
        printf("[ARG] %s %d %d\n", ap4->args[num_args].argname, ap4->args[num_args].idx,  ap4->args[num_args].didx);
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

static inline void read_active_function(activep4_def_t* ap4, char* active_program_dir, char* active_program_name) {
    char program_path[100], args_path[100], memidx_path[100];
    sprintf(program_path, "%s/%s.apo", active_program_dir, active_program_name);
    sprintf(args_path, "%s/%s.args.csv", active_program_dir, active_program_name);
    sprintf(memidx_path, "%s/%s.memidx.csv", active_program_dir, active_program_name);
    read_active_program(ap4, program_path);
    read_active_args(ap4, args_path);
    read_active_memaccess(ap4, memidx_path);
}

/*static inline int insert_active_initial_header(char* buf, uint16_t fid, uint16_t flags) {
    activep4_ih* ap4ih = (activep4_ih*)buf;
    ap4ih->SIG = htonl(ACTIVEP4SIG);
    ap4ih->fid = htons(fid);
    ap4ih->flags = htons(flags);
    return sizeof(activep4_ih);
}*/

/*static inline int insert_active_program(char* buf, activep4_def_t* ap4, activep4_argval* args, int numargs) {
    int offset = 0, i, j;
    int ap4_buf_size = ap4->proglen * sizeof(activep4_instr);
    char* bufptr = buf;
    activep4_instr* code = ap4->code;
    activep4_ih* ih;
    activep4_instr* instr;
    activep4_data_t* data;
    int numinstr = ap4->proglen;
    ih = (activep4_ih*)buf;
    offset += insert_active_initial_header(buf, ap4->fid, 0);
    bufptr += offset;
    // insert arguments
    if(ap4->args_mapped == 0) {
        for(i = 0; i < ap4->num_args; i++) {
            for(j = 0; j < numargs; j++) {
                if(strcmp(args[j].argname, ap4->args[i].argname) == 0) {
                    ap4->args[i].value_idx = j;
                }
            }
        }
        ap4->args_mapped = 1;
    }
    memset(bufptr, 0, sizeof(activep4_data_t));
    data = (activep4_data_t*)bufptr;
    for(i = 0; i < ap4->num_args; i++) {
        data->data[ap4->args[i].didx] = htonl(args[ap4->args[i].value_idx].argval);
    }
    if(ap4->num_args > 0) {
        bufptr += sizeof(activep4_data_t);
        offset += sizeof(activep4_data_t);
        ih->flags = htons(ntohs(ih->flags) | AP4FLAGMASK_OPT_ARGS);
    }
    // insert active program
    memcpy(bufptr, (char*)ap4->code, ap4_buf_size);
    offset += ap4_buf_size;
    return offset;
}*/

static inline int get_active_eof(char* buf, int buflen) {
    if(buflen < sizeof(activep4_instr)) return 0;
    int eof = 0, remaining_bytes = buflen - sizeof(activep4_instr);
    activep4_instr* instr = (activep4_instr*) buf;
    while(instr->opcode != 0 && remaining_bytes >= sizeof(activep4_instr)) {
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

static inline void add_instruction(activep4_def_t* program, pnemonic_opcode_t* instr_set, char* instr) {
    int opcode = pnemonic_to_opcode(instr_set, instr);
    if(opcode >= 0) {
        program->code[program->proglen].flags = 0;
        program->code[program->proglen].opcode = opcode;
        program->proglen++;
    } else printf("Instruction Unknown!");
}

static inline activep4_def_t* construct_memsync_program(int fid, int stageId, pnemonic_opcode_t* instr_set, activep4_def_t* cache) {
    if(stageId > NUM_STAGES || stageId == 0) return NULL;
    if(cache[stageId].fid > 0) return &cache[stageId];
    int rts_inserted = 0, i = 0;
    add_instruction(&cache[stageId], instr_set, "MAR_LOAD_DATA_0"); i++;
    while(i < NUM_STAGES - 1) {
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
    cache[stageId].proglen = i;
    cache[stageId].fid = fid;
    return &cache[stageId];
}

static inline activep4_def_t* construct_memset_program(int fid, int stageId, pnemonic_opcode_t* instr_set, activep4_def_t* cache) {
    if(stageId > NUM_STAGES || stageId == 0) return NULL;
    if(cache[stageId].fid > 0) return &cache[stageId];
    int rts_inserted = 0, i = 0;
    add_instruction(&cache[stageId], instr_set, "MAR_LOAD_DATA_0"); i++;
    while(i < NUM_STAGES - 1) {
        if(i >= stageId) {
            add_instruction(&cache[stageId], instr_set, "MEM_WRITE"); i++;
            add_instruction(&cache[stageId], instr_set, "NOP"); i++;
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
    cache[stageId].proglen = i;
    cache[stageId].fid = fid;
    return &cache[stageId];
}

static inline void construct_dummy_program(activep4_def_t* program, pnemonic_opcode_t* instr_set) {
    add_instruction(program, instr_set, "RTS");
    add_instruction(program, instr_set, "RETURN");
    add_instruction(program, instr_set, "EOF"); 
}

static inline void construct_nop_program(activep4_def_t* program, pnemonic_opcode_t* instr_set, int proglen) {
    if(proglen < 2) proglen = 2;
    int i;
    for(i = 0; i < proglen - 2; i++)
        add_instruction(program, instr_set, "NOP");
    add_instruction(program, instr_set, "RETURN");
    add_instruction(program, instr_set, "EOF");
}

#endif