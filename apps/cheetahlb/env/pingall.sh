#!/bin/bash

NUM_SERVERS=2

if [ "$EUID" -ne 0 ]
then
    echo "Root privileges required (please run as sudo)"
    exit 1
fi

if [ "$#" -gt 0 ]
then
    echo "Setting number of servers to $1"
    NUM_SERVERS=$1
fi

for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    for (( I = 0; I < $NUM_SERVERS; I++ ))
    do
        if [ $SID -ne $I ]
        then
            lxc-attach -n ap4-server-$SID -- ping -c 1 10.0.0.$(($I + 1))
        fi
    done
done