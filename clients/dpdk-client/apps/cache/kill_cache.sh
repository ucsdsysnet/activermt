#!/bin/bash

PIDS=$(ps -ef | grep "active-cache" | tail -n2 | head -n1 | awk '{print $2" "$3}')

sudo kill -9 $PIDS

echo "Killed $PIDS"
