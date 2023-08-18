/**
 * @file activep4.h
 * @author Rajdeep Das (r4das@ucsd.edu)
 * @brief 
 * @version 1.0
 * @date 2023-08-18
 * 
 * @copyright Copyright (c) 2023 Rajdeep Das, University of California San Diego.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 */

#ifndef ACTIVEP4_H
#define ACTIVEP4_H

// #define DEBUG_ACTIVEP4
// #define RECIRC_ENABLED

#define TRUE            1
#define FALSE           0
#define MAXINSTRSET     256
#define MAXARGS         10
#define MAXPROGLEN      50
#define MAXPROGSIZE     512
#define MAXFILESIZE     1024
#define BUFLEN          128
#define MNEMONIC_MAXLEN 50
#define MAX_PROGRAMS    8
#define ACTIVEP4SIG     0x12345678
#define AP4_INSTR_LEN   2
#define AP4_DATA_LEN    4
#define MAX_MEMACCESS   8
#define NUM_STAGES_IG   10
#define NUM_STAGES_EG   10
#define NUM_STAGES      20
// #define MAX_DATA        65536
#define MAX_DATA        94208
#define MAX_FIDX        256
#define FID_RST         255
#define DEFAULT_TI_US   1000000

#define AP4FLAGMASK_OPT_ARGS        0x8000
#define AP4FLAGMASK_FLAG_EOE        0x0100
#define AP4FLAGMASK_FLAG_MARKED     0x0800
#define AP4FLAGMASK_FLAG_REMAPPED   0x0040
#define AP4FLAGMASK_FLAG_ACK        0x0200
#define AP4FLAGMASK_FLAG_INITIATED  0x0400
#define AP4FLAGMASK_FLAG_REQALLOC   0x0010
#define AP4FLAGMASK_FLAG_GETALLOC   0x0020
#define AP4FLAGMASK_FLAG_ALLOCATED  0x0008
#define AP4FLAGMASK_FLAG_PRELOAD    0x0001

#define OPCODE_FLAG_MEMACCESS       0x0001

#define ACTIVE_STATE_TRANSMITTING   0
#define ACTIVE_STATE_ALLOCATING     1
#define ACTIVE_STATE_INITIALIZING   2
#define ACTIVE_STATE_SNAPSHOTTING   3
#define ACTIVE_STATE_SNAPCOMPLETING 4
#define ACTIVE_STATE_REMAPPING      5
#define ACTIVE_STATE_REALLOCATING   6
#define ACTIVE_STATE_UPDATING       7
#define ACTIVE_STATE_DEALLOCATING   8
#define ACTIVE_STATE_DEALLOCWAIT    9

#define ACTIVE_DEFAULT_ARG_MAR      0
#define ACTIVE_DEFAULT_ARG_MBR      1
#define ACTIVE_DEFAULT_ARG_MBR2     2
#define ACTIVE_DEFAULT_ARG_RESULT   3

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>
#include <ctype.h>
#include <errno.h>
#include <assert.h>
#include <arpa/inet.h>

/* Active packet headers. */

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
    uint32_t    start;
    uint32_t    end;
} __attribute__((packed)) activep4_malloc_block_t;

typedef struct {
    activep4_malloc_block_t mem_range[NUM_STAGES];
} __attribute__((packed)) activep4_malloc_res_t;

typedef struct {
    int         stageIdx[NUM_STAGES];
    int         numStages;
    uint32_t    memStart[NUM_STAGES];
    uint32_t    memEnd[NUM_STAGES];
    int         memSize[NUM_STAGES];
} activep4_malloc_t;

typedef struct {
    uint32_t    data[MAX_DATA];
    uint8_t     valid[MAX_DATA];
    uint32_t    mem_start;
    uint32_t    mem_end;
} memory_stage_t;

typedef struct {
    uint8_t         invalid;
    memory_stage_t  sync_data[NUM_STAGES];
    uint8_t         valid_stages[NUM_STAGES];
    uint8_t         syncmap[NUM_STAGES];
    uint16_t        fid;
    uint16_t        version;
    uint16_t        sync_version;
    uint64_t        sync_start_time;
    uint64_t        sync_end_time;
    void*           hash_function;
} memory_t;

typedef struct {
    activep4_instr  code[MAXPROGLEN];
    int             proglen;
} active_mutant_t;

typedef struct {
    uint16_t        pid;
    char            name[100];
    activep4_instr  code[MAXPROGLEN];
    int             num_accesses;
    int             access_idx[NUM_STAGES];
    int             demand[NUM_STAGES];
    int             proglen;
    int             iglim;
    active_mutant_t mutant;
} activep4_def_t;

/* Instruction set. */

typedef struct {
    char        mnemonic[MNEMONIC_MAXLEN];
    char        action[MNEMONIC_MAXLEN];
    int         options;
    uint16_t    flags;
} opcode_action_map_t;

typedef struct {
    opcode_action_map_t map[MAXINSTRSET];
    int                 num_instr;
} pnemonic_opcode_t;

typedef struct {
    uint8_t     is_initializing;
    uint8_t     allocation_is_active;
    uint8_t     memwrite_is_active;
    uint64_t    allocation_request_start_ts;
    uint64_t    allocation_request_stop_ts;
    uint64_t    mem_write_start_ts;
    uint64_t    mem_write_stop_ts;
} active_telemetry_t;

typedef struct {
    int                 id;
    int                 fid;
    uint8_t             active_tx_enabled;
    uint8_t             active_heartbeat_enabled;
    uint8_t             is_active;
    uint8_t             status;
    uint8_t             active_timer_enabled;
    uint64_t            ctrl_ts_lastsent;
    uint64_t            ctrl_timer_lasttick;
    active_telemetry_t  telemetry;
    pnemonic_opcode_t*  instr_set;   
    activep4_def_t*     programs[MAX_PROGRAMS];
    int                 num_programs;
    int                 current_pid;
    memory_t            allocation;
    memory_t            membuf;
    uint8_t             is_elastic;
    activep4_data_t     data;
    uint32_t            ipv4_srcaddr;
    void*               app_context;
    int                 timer_interval_us;
    void                (*timer)(void*);
    void                (*tx_mux)(void*, void*, int*);
    void                (*tx_handler)(void*, activep4_data_t*, memory_t*, void*);
    void                (*rx_handler)(void*, activep4_ih*, activep4_data_t*, void*, void*);
    int                 (*memory_consume)(memory_t*, void*);
    int                 (*memory_invalidate)(memory_t*, void*);
    int                 (*memory_reset)(memory_t*, void*);
    void                (*shutdown)(int, void*);
    void                (*on_allocation)(void*);
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

static inline int is_memaccess(pnemonic_opcode_t* instr_set, int opcode) {
    if(instr_set->map[opcode].flags & OPCODE_FLAG_MEMACCESS) return 1;
    return 0;
}

static inline int read_opcode_action_map(char* filename, pnemonic_opcode_t* instr_set) {
    int i = 0, tokidx;
    char buf[BUFLEN];
    const char* tok;
    FILE* fp = fopen(filename, "r");
    assert(fp != NULL);
    while(fgets(buf, BUFLEN, fp) != NULL) {
        tokidx = 0;
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(isspace(tok[0])) continue;
            if(tokidx == 0) strcpy(instr_set->map[i].mnemonic, tok);
            else if(tokidx == 1) strcpy(instr_set->map[i].action, tok);
            else instr_set->map[i].options = atoi(tok);
            tokidx++;
        }
        if(strncmp(instr_set->map[i].mnemonic, "MEM", 3) == 0) {
            instr_set->map[i].flags |= OPCODE_FLAG_MEMACCESS;
        }
        i++;
    }
    fclose(fp);
    instr_set->num_instr = i;
    return 0;
}

static inline int read_active_program(activep4_def_t* ap4, char* prog_file) {
    FILE* fp = fopen(prog_file, "rb");
    assert(fp != NULL);
    activep4_instr* code = ap4->code;
    fseek(fp, 0, SEEK_END);
    int ap4_size = ftell(fp);
    rewind(fp);
    char fbuf[MAXFILESIZE];
    assert(fread(fbuf, ap4_size, 1, fp) > 0);
    fclose(fp);
    int i = 0, j = 0;
    #ifdef DEBUG_ACTIVEP4
    printf("[Active Program]\n");
    #endif
    while(i < MAXPROGLEN && j < ap4_size) {
        code[i].flags = fbuf[j];
        code[i].opcode = fbuf[j + 1];
        #ifdef DEBUG_ACTIVEP4
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
    assert(fp != NULL);
    char buf[50];
    const char* tok;
    int memidx[NUM_STAGES], i = 0, iglim = -1;
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
    #ifdef DEBUG_ACTIVEP4
    printf("[ACTIVEP4] Read program memory access pattern: %d stages (", ap4->num_accesses);
    #endif
    for(i = 0; i < ap4->num_accesses; i++) {
        ap4->access_idx[i] = memidx[i];
        ap4->demand[i] = 1; // default (elastic).
        #ifdef DEBUG_ACTIVEP4
        printf("%d,", memidx[i]);
        #endif
    }
    #ifdef DEBUG_ACTIVEP4
    printf(") ingress limit %d\n", iglim);
    #endif
}

static inline void read_active_function(activep4_def_t* ap4, char* active_program_dir, char* active_program_name) {
    char program_path[100], memidx_path[100];
    sprintf(program_path, "%s/%s.apo", active_program_dir, active_program_name);
    sprintf(memidx_path, "%s/%s.memidx.csv", active_program_dir, active_program_name);
    read_active_program(ap4, program_path);
    read_active_memaccess(ap4, memidx_path);
}

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
    assert(opcode >= 0);
    program->code[program->proglen].flags = 0;
    program->code[program->proglen].opcode = opcode;
    program->proglen++;
}

static inline activep4_def_t* construct_memsync_program(int fid, int stageId, pnemonic_opcode_t* instr_set, activep4_def_t* cache) {
    if(stageId > NUM_STAGES) return NULL;
    if(cache[stageId].proglen > 0) return &cache[stageId];
    int rts_inserted = 0, i = 0;
    while(i < NUM_STAGES - 1) {
        if(i >= stageId) {
            add_instruction(&cache[stageId], instr_set, "MEM_READ"); i++;
            add_instruction(&cache[stageId], instr_set, "MBR_STORE"); i++;
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
    // cache[stageId].fid = fid;
    #ifdef DEBUG_ACTIVEP4
    printf("[MEMSYNC PROGRAM]\n");
    activep4_def_t* program = &cache[stageId];
    for(int j = 0; j < i; j++) {
        printf("[%d]\t%d\n", program->code[j].flags, program->code[j].opcode);
    }
    #endif
    return &cache[stageId];
}

static inline activep4_def_t* construct_memset_program(int fid, int stageId, pnemonic_opcode_t* instr_set, activep4_def_t* cache) {
    if(stageId > NUM_STAGES) return NULL;
    if(cache[stageId].proglen > 0) return &cache[stageId];
    int i = 0;
    while(i < NUM_STAGES - 1) {
        if(i == stageId) {
            add_instruction(&cache[stageId], instr_set, "MEM_WRITE"); i++;
            break;
        } else {
            add_instruction(&cache[stageId], instr_set, "NOP"); i++;
        }
    }
    add_instruction(&cache[stageId], instr_set, "RETURN"); i++;
    add_instruction(&cache[stageId], instr_set, "EOF"); i++;
    cache[stageId].proglen = i;
    // cache[stageId].fid = fid;
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

static inline int get_memory_stage_id(int idx) {
    if(idx < NUM_STAGES) return idx;
    return (idx - NUM_STAGES_IG) % NUM_STAGES_EG + NUM_STAGES_IG;
}

/*
memcfg contains a set of memory stages not necessarily in order of accesses.
ap4 contains order of accesses and number of accesses.
task is to find a program that can be assigned the set of memory stages.
*/
static inline void mutate_active_program(activep4_def_t* ap4, memory_t* memcfg, int NOP_OPCODE, pnemonic_opcode_t* instr_set) {

    // int min_distance[NUM_STAGES];
    int access_idx_normalized[NUM_STAGES];
    for(int i = 0; i < ap4->num_accesses; i++) {
        access_idx_normalized[i] = (ap4->access_idx[i] < NUM_STAGES_IG) ? ap4->access_idx[i] : ap4->access_idx[i] % NUM_STAGES_EG + NUM_STAGES_IG;
        // min_distance[i] = (i == 0) ? ap4->access_idx[i] : ap4->access_idx[i] - ap4->access_idx[i - 1];
    }

    int original = 1;
    for(int i = 0; i < ap4->num_accesses; i++) {
        if(memcfg->valid_stages[access_idx_normalized[i]] == 0) original = 0;
    }

    if(original) {
        #ifdef DEBUG_ACTIVEP4
        printf("[DEBUG_ACTIVEP4] Program mutation not required.\n");
        #endif
        return;
    }
    
    int access_idx_allocated[NUM_STAGES], block_start, block_end, offset;

    memset(&access_idx_allocated, 0, NUM_STAGES * sizeof(int));

    int j = 0;
    for(int i = 0; i < NUM_STAGES; i++) {
        if(memcfg->valid_stages[i] == 1) access_idx_allocated[j++] = i;
    }

    #ifdef RECIRC_ENABLED

    // for(int i = 0; i < ap4->num_accesses; i++) printf("%d ", access_idx_normalized[i]);
    // printf("\n");

    uint8_t unique_accesses[NUM_STAGES];
    memset(unique_accesses, 0, NUM_STAGES);
    for(int i = 0; i < ap4->num_accesses; i++) {
        int idx = access_idx_normalized[i];
        unique_accesses[idx] = 1;
    }
    int num_unique_accesses = 0;
    for(int i = 0; i < NUM_STAGES; i++) num_unique_accesses += unique_accesses[i];

    assert(j == num_unique_accesses);

    int access_idx[NUM_STAGES];
    int assigned[NUM_STAGES];

    memcpy(assigned, access_idx_allocated, j * sizeof(int));

    // 1. assign allocated stages to memory accesses.
    for(int k = 0; k < j; k++) {
        int init = assigned[k];
        access_idx[0] = init;
        assigned[k] = -1;
        for(int i = 1; i < ap4->num_accesses; i++) {
            int mindist = min_distance[i];
            for(int m = k + 1; m != k; m = (m + 1)%j) {
                if(assigned[m] != -1);
            }
        }
    }

    int access_repeats[NUM_STAGES];
    memset(access_repeats, -1, sizeof(access_repeats));
    for(int i = 0; i < ap4->num_accesses; i++) {
        for(int j = 0; j < i; j++) {
            int rep_idx_last = -1;
            if(access_idx_normalized[j] == access_idx_normalized[i]) {
                rep_idx_last = j;
            }
            if(rep_idx_last >= 0) access_repeats[rep_idx_last] = i;
        }
    }

    // for(int i = 0; i < ap4->num_accesses; i++) printf("%d ", access_repeats[i]);
    // printf("\n");

    int access_idx_expanded[NUM_STAGES], idx = 0;
    uint8_t filled[NUM_STAGES];
    memset(filled, 0, NUM_STAGES);
    for(int i = 0; i < j; i++) {
        if(filled[idx]) idx++;
        access_idx_expanded[idx] = access_idx_allocated[i];
        if(access_repeats[idx] >= 0) {
            access_idx_expanded[access_repeats[idx]] = access_idx_allocated[i];
            filled[access_repeats[idx]] = 1;
        }
        idx++;
    }

    // for(int i = 0; i < ap4->num_accesses; i++) printf("%d ", access_idx_expanded[i]);
    // printf("\n");
    #else
    assert(j == ap4->num_accesses);
    #endif

    active_mutant_t* program = &ap4->mutant;

    #ifdef DEBUG_ACTIVEP4
    printf("[DEBUG_ACTIVEP4] program length=%d, %d num accesses.\n", ap4->proglen, ap4->num_accesses);
    #endif

    int allocation_map[MAXPROGLEN], allocIdx = 0, increase = 0, stage_idx, delta;
    memset(allocation_map, -1, MAXPROGLEN * sizeof(int));
    for(int i = 0; i < ap4->proglen; i++) {
        if(allocIdx >= ap4->num_accesses) break;
        if(is_memaccess(instr_set, ap4->code[i].opcode)) {
            stage_idx = get_memory_stage_id(i);
            #ifdef DEBUG_ACTIVEP4
            printf("[DEBUG_ACTIVEP4] memaccess %d -> %d\n", i, access_idx_allocated[allocIdx]);
            #endif
            delta = access_idx_allocated[allocIdx] - stage_idx - increase;
            if(delta < 0) delta += (NUM_STAGES - NUM_STAGES_IG);
            increase += delta;
            allocation_map[i] = access_idx_allocated[allocIdx++]; // assumes ordered memory accesses.
        }
    }
    program->proglen = ap4->proglen + increase;

    assert(program->proglen <= MAXPROGLEN);

    memset(&program->code, 0, MAXPROGLEN * sizeof(activep4_instr));

    for(int i = 0; i < program->proglen; i++) program->code[i].opcode = NOP_OPCODE;

    block_end = ap4->proglen - 1;
    while(j > 0) {
        j--;
        block_start = ap4->access_idx[j];
        offset = access_idx_allocated[j] - get_memory_stage_id(ap4->access_idx[j]);
        if(offset < 0) offset += (NUM_STAGES - NUM_STAGES_IG);
        for(int i = block_end; i >= block_start; i--) {
            program->code[i + offset] = ap4->code[i];
        }
        block_end = block_start - 1;
    }

    for(int i = 0; i < ap4->access_idx[0]; i++) {
        program->code[i] = ap4->code[i];
    }

    #ifdef DEBUG_ACTIVEP4
    printf("[PID %d] program size increased by %d, mutant:\n", ap4->pid, increase);
    for(int i = 0; i < program->proglen; i++) {
        printf("[%d]\t%d\n", program->code[i].flags, program->code[i].opcode);
    }
    #endif
}

static inline void clear_memory_regions(memory_t* mem) {
    for(int i = 0; i < NUM_STAGES; i++) {
        memset(&mem->sync_data[i].data, 0, MAX_DATA * sizeof(uint32_t));
        memset(&mem->sync_data[i].valid, 0, MAX_DATA * sizeof(uint8_t));
    }
}

static inline void set_memory_demand(activep4_context_t* ctxt, int demand) {
    if(demand > 1) ctxt->is_elastic = 0;
    else ctxt->is_elastic = 1;
    for(int i = 0; i < ctxt->programs[ctxt->current_pid]->num_accesses; i++)
        ctxt->programs[ctxt->current_pid]->demand[i] = demand;
}

static inline void set_memory_demand_per_stage(activep4_context_t* ctxt, int* demand) {
    int is_elastic = 1;
    for(int i = 0; i < ctxt->programs[ctxt->current_pid]->num_accesses; i++) {
        ctxt->programs[ctxt->current_pid]->demand[i] = demand[i];
        if(demand[i] > 1) is_elastic = 0;
    }
    ctxt->is_elastic = is_elastic;
}

static inline void set_memory_allocation(activep4_context_t* ctxt, memory_t* allocation) {
    memcpy(&ctxt->allocation, allocation, sizeof(memory_t));
}

#endif