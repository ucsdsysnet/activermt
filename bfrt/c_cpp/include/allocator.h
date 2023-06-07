#ifndef ALLOCATOR_H
#define ALLOCATOR_H

#include <unordered_map>
#include <vector>

#include "common.h"

#define NUM_STAGES_TOTAL NUM_STAGES_PIPE*2

typedef struct {
    int num_memaccess;
    int* memaccess_idx;
    int* demand;
} memcfg_t;

typedef struct {
    int fid;
    std::shared_ptr<active_program_t> program;
    memcfg_t memcfg;
    int ig_lim;
    int prog_maxlen;
    bool allow_recirculations;
    int** A;
    int* LB;
    int* UB;
    std::vector<memcfg_t> enumeration;
} program_cfg_t;

typedef struct {
    int metric;
    int objective;
    int matrix[MAXINSTANCES][NUM_STAGES_TOTAL];
    int elastic_offset[NUM_STAGES_TOTAL];
    // frag
} allocation_t;

#endif