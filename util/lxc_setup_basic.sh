#!/bin/bash

sudo lxc-stop -n ap4-client
sudo lxc-stop -n ap4-server

noOfVeths=8
if [ $# -eq 1 ]; then 
    noOfVeths=$1
fi
echo "No of Veths is $noOfVeths"

idx=0
while [ $idx -lt $noOfVeths ]
do
    intf="veth$(($idx*2))"
    if sudo ip link show $intf &> /dev/null; then
        sudo ip link delete $intf type veth
    fi
    idx=$((idx + 1))
done
idx=125
intf="veth$(($idx*2))"
if sudo ip link show $intf &> /dev/null; then
    sudo ip link delete $intf type veth
fi

let "vethpairs=$noOfVeths/2"
last=`expr $vethpairs - 1`
veths=`seq 0 1 $last`

for i in $veths; do
    echo "setting veth link "$i
    intf0="veth$(($i*2))"
    intf1="veth$(($i*2+1))"
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
done

sudo lxc-start -n ap4-client
sudo lxc-start -n ap4-server

LXC_PID_CLIENT=$(sudo lxc-info -pHn ap4-client)
LXC_PID_SERVER=$(sudo lxc-info -pHn ap4-server)

sudo ip link set dev veth5 netns $LXC_PID_CLIENT name eth1
sudo ip link set dev veth7 netns $LXC_PID_SERVER name eth1

sudo lxc-attach -n ap4-client -- ip link set dev eth1 up
sudo lxc-attach -n ap4-server -- ip link set dev eth1 up
sudo lxc-attach -n ap4-client -- ifconfig eth1 10.0.0.1 netmask 255.255.255.0
sudo lxc-attach -n ap4-server -- ifconfig eth1 10.0.0.2 netmask 255.255.255.0

sudo lxc-attach -n ap4-client -- openvpn --mktun --dev tun0
sudo lxc-attach -n ap4-server -- openvpn --mktun --dev tun0

sudo lxc-attach -n ap4-client -- ip link set tun0 up
sudo lxc-attach -n ap4-server -- ip link set tun0 up
sudo lxc-attach -n ap4-client -- ip addr add 10.0.2.1/24 dev tun0
sudo lxc-attach -n ap4-server -- ip addr add 10.0.2.2/24 dev tun0