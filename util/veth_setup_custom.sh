#!/bin/bash

# set number of veths
noOfVeths=148
if [ $# -eq 1 ]; then 
    noOfVeths=$1
fi
echo "No of Veths is $noOfVeths"

let "vethpairs=$noOfVeths/2"
last=`expr $vethpairs - 1`
veths=`seq 0 1 $last`

# add CPU port
veths+=" 125"

for i in $veths; do
    # if [ $i -lt 8 ]
    # then
    echo "setting regular link "$i
    intf0="veth$(($i*2))"
    intf1="veth$(($i*2+1))"
    if ! ip link show $intf0 &> /dev/null; then
        ip link add name $intf0 type veth peer name $intf1 &> /dev/null
    fi
    ip link set dev $intf0 up
    sysctl net.ipv6.conf.$intf0.disable_ipv6=1 &> /dev/null
    sysctl net.ipv6.conf.$intf1.disable_ipv6=1 &> /dev/null
    ip link set dev $intf0 up mtu 10240
    ip link set dev $intf1 up mtu 10240
    TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
    for TOE_OPTION in $TOE_OPTIONS 
    do
        /sbin/ethtool --offload $intf0 "$TOE_OPTION" off &> /dev/null
        /sbin/ethtool --offload $intf1 "$TOE_OPTION" off &> /dev/null
    done
    # else
    #     echo "setting patched link "$i
    #     intf0="veth$(($i*2))"
    #     intf1="veth$(($i*2+64))"
    #     if ! ip link show $intf0 &> /dev/null; then
    #         ip link add name $intf0 type veth peer name $intf1 &> /dev/null
    #     fi
    #     ip link set dev $intf0 up
    #     sysctl net.ipv6.conf.$intf0.disable_ipv6=1 &> /dev/null
    #     sysctl net.ipv6.conf.$intf1.disable_ipv6=1 &> /dev/null
    #     ip link set dev $intf0 up mtu 10240
    #     ip link set dev $intf1 up mtu 10240
    #     TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
    #     for TOE_OPTION in $TOE_OPTIONS 
    #     do
    #         /sbin/ethtool --offload $intf0 "$TOE_OPTION" off &> /dev/null
    #         /sbin/ethtool --offload $intf1 "$TOE_OPTION" off &> /dev/null
    #     done
    # fi
done
