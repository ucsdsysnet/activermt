#ifndef MEMORY_H
#define MEMORY_H

#include <rte_hash_crc.h>
#include <rte_memcpy.h>
#include "types.h"

static inline uint32_t get_memory_addr(memory_map_t* mmap, uint32_t key, int stage_id) {
    hash_sig_t addr = rte_hash_hash(mmap->hash[stage_id], (void*)&key);
    assert(addr >= mmap->memalloc->sync_data[stage_id].mem_start && addr <= mmap->memalloc->sync_data[stage_id].mem_end);
    return (uint32_t)addr;
}

static inline void update_memory_map(memory_map_t* mmap, memory_t* mem_updt) {
    for(int i = 0; i < NUM_STAGES; i++) {
        if(!mem_updt->valid_stages[i]) continue;
        struct rte_hash_parameters hash_params = {
            .name = NULL,
            .entries = mem_updt->sync_data[i].mem_end - mem_updt->sync_data[i].mem_start + 1,
            .key_len = sizeof(uint32_t),
            .hash_func = rte_hash_crc,
            .hash_func_init_val = 0
        };
        mmap->hash[i] = rte_hash_create(&hash_params);
    }
    rte_memcpy(&mmap->memalloc, mem_updt, sizeof(memory_t));
}

static inline void remap_memory_objects(memory_map_t* mmap) {
    switch(mmap->remap_algo) {
        case MEM_REMAP_TOPK:
            break;
        case MEM_REMAP_RAND:
            break;
        default:
            break;
    }
}

#endif