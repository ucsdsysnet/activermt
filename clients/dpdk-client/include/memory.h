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

static inline void consume_memory_objects(memory_t* snapshot, activep4_context_t* ctxt) {
    if(ctxt->memory_consume)
        ctxt->memory_consume(snapshot, ctxt->app_context);
}

static inline void reset_memory_region(memory_t* region, activep4_context_t* ctxt) {
    if(ctxt->memory_reset)
        ctxt->memory_reset(region, ctxt->app_context);
}

#endif