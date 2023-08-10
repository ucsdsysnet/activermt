#!/bin/bash

ARP_TABLE_FILE=arp_table.csv
SERVER_PREFIX=ap4-server-
NUM_SERVERS=6

ADDRS_IPV4=()
ADDRS_MAC=()

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
    IP_ADDR=$(sudo lxc-attach -n $SERVER_PREFIX$SID -- ifconfig eth1 | grep 'inet ' | tr -s ' ' | cut -f3 -d' ')
    HW_ADDR=$(sudo lxc-attach -n $SERVER_PREFIX$SID -- ifconfig eth1 | grep 'ether' | tr -s ' ' | cut -f3 -d' ')
    ADDRS_IPV4[$SID]=$IP_ADDR
    ADDRS_MAC[$SID]=$HW_ADDR
done

: > $ARP_TABLE_FILE

for (( I = 0; I < $NUM_SERVERS; I++ ))
do
    echo "MAC (Server $I): ${ADDRS_IPV4[I]} -> ${ADDRS_MAC[I]}"
    echo "${ADDRS_IPV4[I]},${ADDRS_MAC[I]},$I" >> $ARP_TABLE_FILE
done