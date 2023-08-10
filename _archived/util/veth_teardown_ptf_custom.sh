#!/bin/bash

noOfVeths=12
if [ $# -eq 1 ]; then 
    noOfVeths=$1
fi
echo "No of Veths is $noOfVeths"

idx=0
while [ $idx -lt $noOfVeths ]
do 
    intf="veth$(($idx*2))"
    if ip link show $intf &> /dev/null; then
        ip link delete $intf type veth
    fi
    idx=$((idx + 1))
done
