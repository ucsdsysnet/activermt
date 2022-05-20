#!/bin/bash

SERVER_PREFIX=ap4-server-
NUM_SERVERS=2

ADDRS_IPV4=()
ADDRS_MAC=()

for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    IP_ADDR=$(sudo lxc-attach -n $SERVER_PREFIX$SID -- ifconfig eth1 | grep 'inet ' | tr -s ' ' | cut -f3 -d' ')
    HW_ADDR=$(sudo lxc-attach -n $SERVER_PREFIX$SID -- ifconfig eth1 | grep 'ether' | tr -s ' ' | cut -f3 -d' ')
    ADDRS_IPV4[$SID]=$IP_ADDR
    ADDRS_MAC[$SID]=$HW_ADDR
done

for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    for (( I = 0; I < $NUM_SERVERS; I++ ))
    do
        if [ $SID -ne $I ]
        then
            echo "Setting MAC (Server $SID): ${ADDRS_IPV4[I]} -> ${ADDRS_MAC[I]}"
            sudo lxc-attach $SERVER_PREFIX$SID -- arp -s "${ADDRS_IPV4[I]}" "${ADDRS_MAC[I]}" -i eth1
        fi
    done
done