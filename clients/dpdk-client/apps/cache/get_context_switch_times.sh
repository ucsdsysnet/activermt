#!/bin/bash

CTXT_END=$(cat rte_log_active_cache.log | grep "context switch complete" | cut -f6 -d" ")
CTXT_START=$(cat rte_log_active_cache.log | grep "context switch init" | cut -f5 -d" ")
CTXT_MID=$(cat rte_log_active_cache.log | grep "switching to" | cut -f5 -d" ")

echo "$CTXT_START,$CTXT_END,$CTXT_MID" > context_switch_time_ms.csv