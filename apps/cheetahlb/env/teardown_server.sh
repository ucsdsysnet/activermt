#!/bin/bash

NUM_SERVERS=6
VETH_OFFSET=2

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

noOfVeths=$(($NUM_SERVERS * 2))
echo "No of Veths is $noOfVeths"

idx=$VETH_OFFSET
noOfVeths=$(($noOfVeths + 2*$VETH_OFFSET))
while [ $idx -lt $noOfVeths ]
do
    intf="veth$(($idx*2))"
    if sudo ip link show $intf &> /dev/null; then
        sudo ip link delete $intf type veth
    fi
    idx=$((idx + 1))
done

for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    sudo lxc-stop -n ap4-server-$SID
done