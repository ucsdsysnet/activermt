#ifndef MONITOR_H
#define MONITOR_H

#include <rte_log.h>
#include <rte_timer.h>

#include "../../../../headers/activep4.h"
#include "common.h"

int 
memory_consume_monitor(memory_t* mem, void* context) { 

    cache_context_t* ctxt = (cache_context_t*)context;

    if(ctxt->timer_snapshot_trigger == 1) {
        rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] received objects.\n");
        ctxt->timer_snapshot_trigger = 0;
        ctxt->timer_deallocate_trigger = 1;
    }

    return 0; 
}

int 
memory_invalidate_monitor(memory_t* mem, void* context) { return 0; }

int 
memory_reset_monitor(memory_t* mem, void* context) { return 0; }

void 
timer_monitor(void* arg) {

    activep4_context_t* ctxt = (activep4_context_t*)arg;
	cache_context_t* cache_ctxt = (cache_context_t*)ctxt->app_context;

    if(cache_ctxt->timer_deallocate_trigger) {
        cache_ctxt->timer_deallocate_trigger = 0;
        cache_ctxt->timer_ctxswtch_trigger = 1;
        ctxt->status = ACTIVE_STATE_DEALLOCATING;
        ctxt->timer_interval_us = 1000;
    } else if(cache_ctxt->timer_ctxswtch_trigger) {
        if(ctxt->status == ACTIVE_STATE_TRANSMITTING) {
            cache_ctxt->timer_ctxswtch_trigger = 0;
            rte_log(RTE_LOG_INFO, RTE_LOGTYPE_USER1, "[MONITOR] switching to cache ... \n");
            context_switch_cache(ctxt);
            rte_delay_ms(10);
            memset(&ctxt->allocation, 0, sizeof(memory_t));
            memset(&ctxt->membuf, 0, sizeof(memory_t));
            ctxt->allocation.fid = ctxt->fid;
            ctxt->status = ACTIVE_STATE_INITIALIZING;
            assert(ctxt->current_pid == PID_CACHEREAD);
        } 
    } else {
        cache_ctxt->timer_snapshot_trigger = 1;
        ctxt->status = ACTIVE_STATE_SNAPSHOTTING;
    }
}

#endif