#!/bin/bash

PIDS=$(ps -ef | grep "ap4-netproxy" | tail -n2 | head -n1 | awk '{print $2" "$3}')

sudo kill -9 $PIDS

echo "Killed $PIDS"
