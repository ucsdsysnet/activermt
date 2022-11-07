#ifndef MEMORY_H
#define MEMORY_H

#include <rte_hash_crc.h>
#include <rte_memcpy.h>
#include "types.h"

static inline void consume_memory_objects(memory_t* snapshot, activep4_context_t* ctxt) {
    if(ctxt->memory_consume)
        ctxt->memory_consume(snapshot);
}

static inline void reset_memory_region(memory_t* region, activep4_context_t* ctxt) {
    if(ctxt->memory_reset)
        ctxt->memory_reset(region);
}

#endif