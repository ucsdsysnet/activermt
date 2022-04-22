#!/bin/bash

if [ $EUID -ne 0 ]; then
    echo "ERROR: This script requires root privileges. Please, use sudo"
    exit 1
fi

for intf in `ip link show | cut -d: -f2 | grep port`; do
    sudo ip link delete $intf
done

for intf in `ip link show | cut -d: -f2 | grep cpu_`; do
    sudo ip link delete $intf
done
