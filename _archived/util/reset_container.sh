#!/bin/bash

if [ "$#" -lt 2 ]
then
    echo "Usage: reset_veth.sh <veth_pair_idx> <container_name>"
    exit 1
fi

VETHIDX=$1
CONTAINERID=$2

sudo lxc-stop -n $CONTAINERID
sudo lxc-start -n $CONTAINERID

intf0=veth$(($VETHIDX))
intf1=veth$(($VETHIDX+1))

if sudo ip link show $intf0 &> /dev/null; then
    sudo ip link delete $intf0 type veth
fi
if sudo ip link show $intf1 &> /dev/null; then
    sudo ip link delete $intf1 type veth
fi

if ! sudo ip link show $intf0 &> /dev/null; then
    sudo ip link add name $intf0 type veth peer name $intf1 &> /dev/null
fi
sudo ip link set dev $intf0 up
sysctl net.ipv6.conf.$intf0.disable_ipv6=1 &> /dev/null
sysctl net.ipv6.conf.$intf1.disable_ipv6=1 &> /dev/null
sudo ip link set dev $intf0 up mtu 10240
sudo ip link set dev $intf1 up mtu 10240
TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
for TOE_OPTION in $TOE_OPTIONS 
do
    /sbin/ethtool --offload $intf0 "$TOE_OPTION" off &> /dev/null
    /sbin/ethtool --offload $intf1 "$TOE_OPTION" off &> /dev/null
done

LXC_PID_CLIENT=$(sudo lxc-info -pHn ap4-client)

sudo ip link set dev veth5 netns $LXC_PID_CLIENT name eth1

sudo lxc-attach -n ap4-client -- ip link set dev eth1 up
sudo lxc-attach -n ap4-client -- ifconfig eth1 10.0.0.1 netmask 255.255.255.0
sudo lxc-attach -n ap4-client -- openvpn --mktun --dev tun0
sudo lxc-attach -n ap4-client -- ip link set tun0 up
sudo lxc-attach -n ap4-client -- ip addr add 10.0.2.1/24 dev tun0