#ifndef MEMORY_H
#define MEMORY_H

#include <rte_hash_crc.h>
#include <rte_memcpy.h>
#include "types.h"

static inline void update_addressing_hashtable(memory_t* mem, int memory_size) {
    if(mem->hash_function != NULL) return;
    char* hash_name = "ap4_hash";
	struct rte_hash_parameters hash_params = {
		.name = hash_name,
		.entries = memory_size,
		.key_len = sizeof(uint16_t),
		.hash_func = rte_hash_crc,
		.hash_func_init_val = 0
	};
    mem->hash_function = (void*)rte_hash_create(&hash_params);
    printf("Hash params: %d entries, %d keylen\n", hash_params.entries, hash_params.key_len);
}

static inline int consume_memory_objects(memory_t* snapshot, activep4_context_t* ctxt) {
    if(ctxt->memory_consume)
        return ctxt->memory_consume(snapshot, ctxt->app_context);
    return 0;
}

static inline int reset_memory_region(memory_t* region, activep4_context_t* ctxt) {
    if(ctxt->memory_reset)
        return ctxt->memory_reset(region, ctxt->app_context);
    return 0;
}

static inline int get_next_valid_stage(activep4_context_t* ctxt, active_control_state_t* ctrlstat) {
    for(int i = ctrlstat->current_stage; i < NUM_STAGES; i++) {
        if(ctxt->allocation.valid_stages[i] && ctxt->syncmap[i]) {
            ctrlstat->current_stage = i;
            return i;
        }
    }
    return -1;
}

static inline int get_next_valid_index(activep4_context_t* ctxt, active_control_state_t* ctrlstat) {
    if(ctrlstat->current_stage < 0) return -1;
    if(ctrlstat->current_index < ctxt->allocation.sync_data[ctrlstat->current_stage].mem_start)
        ctrlstat->current_index = ctxt->allocation.sync_data[ctrlstat->current_stage].mem_start;
    for(int i = ctrlstat->current_index; i <= ctxt->allocation.sync_data[ctrlstat->current_stage].mem_end; i++) {
        if(!ctxt->allocation.sync_data[ctrlstat->current_stage].valid[i]) {
            ctrlstat->current_index = i;
            return i;
        }
    }
    return -1;
}

#endif