#!/bin/bash

NUM_SERVERS=6
VETH_OFFSET=2

if [ "$EUID" -ne 0 ]
then
    echo "Root privileges required (please run as sudo)"
    exit 1
fi

if [ -z "$(lsb_release -c | grep focal)" ]
then
    echo "Ubuntu focal distribution required"
    exit 1
else
    apt-get install lxc
fi

if [ -z "$ACTIVEP4_SRC" ]
then
    echo "ACTIVEP4_SRC env variable not set"
    exit 1
fi

if [ "$#" -gt 0 ]
then
    echo "Setting number of servers to $1"
    NUM_SERVERS=$1
fi

# set up veth pairs
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

let "vethpairs=$noOfVeths/2"
last=`expr $vethpairs - 1`
veths=`seq $VETH_OFFSET 1 $last`

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

# set up bridged network
ip link set ap4br0 down
brctl delbr ap4br0
if [ -z "$(brctl show | grep ap4br0)" ]
then
    echo "Setting up bridged network..."
    brctl addbr ap4br0
    brctl addif ap4br0 ens4
    for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
    do
        VETHIDX=veth$(($SID*2))
        echo "Adding $VETHIDX to ap4br0..."
        brctl addif ap4br0 $VETHIDX
    done
    ip link set ap4br0 up
    if [ -d "/proc/sys/net/bridge" ]
    then
        BR_FILTERS=$(ls /proc/sys/net/bridge | grep bridge-nf)
        for BRF in $BR_FILTERS
        do
            echo "Disabling filter $BRF"
            echo 0 > /proc/sys/net/bridge/$BRF
        done
    fi
fi

# set up containers
for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    if [ -z "$(lxc-ls | grep ap4-server-$SID)" ]
    then
        echo "no existing containers found for server $SID: creating..."
        sudo DOWNLOAD_KEYSERVER="hkp://keyserver.ubuntu.com" lxc-create -t download -n ap4-server-$SID -- -d ubuntu -r focal -a amd64
        GUEST_SRC_PATH=/var/lib/lxc/ap4-server-$SID/rootfs/root/activep4
        LXC_CONFIG_FILE=/var/lib/lxc/ap4-server-$SID/config
        mkdir -p $GUEST_SRC_PATH
        if [ -z "$(cat $LXC_CONFIG_FILE | grep $ACTIVEP4_SRC)" ]
        then
            echo "container ap4-server-$SID not configured: configuring..."
            echo "" >> $LXC_CONFIG_FILE
            echo "lxc.cgroup.devices.allow = c 10:200 rwm" >> $LXC_CONFIG_FILE
            echo "lxc.mount.entry = $ACTIVEP4_SRC $GUEST_SRC_PATH none bind 0 0" >> $LXC_CONFIG_FILE
            echo "lxc.mount.entry = /dev/net/tun /var/lib/lxc/ap4-server-$SID/rootfs/dev/net/tun none bind,create=file" >> $LXC_CONFIG_FILE
        fi
    fi

    sudo lxc-stop -n ap4-server-$SID
    sudo lxc-start -n ap4-server-$SID
    sudo lxc-wait -n ap4-server-$SID -s RUNNING

    echo "preparing ap4-server-$SID..."

    sleep 10

    lxc-attach -n ap4-server-$SID -- apt-get update
    lxc-attach -n ap4-server-$SID -- apt-get install -y net-tools openvpn python python3-pip tcpdump screen
    lxc-attach -n ap4-server-$SID -- pip3 install --pre scapy

    LXC_PID_SERVER=$(sudo lxc-info -pHn ap4-server-$SID)
    IPADDR_TUN=10.0.2.$(($SID + 1))
    IPADDR_ETH=10.0.0.$(($SID + 1))
    VETHIDX=$(($SID*2 + 1 + 2*$VETH_OFFSET))

    sudo ip link set dev veth$VETHIDX netns $LXC_PID_SERVER name eth1

    sudo lxc-attach -n ap4-server-$SID -- ip link set eth1 up
    sudo lxc-attach -n ap4-server-$SID -- ip addr add $IPADDR_ETH/24 dev eth1
    sudo lxc-attach -n ap4-server-$SID -- openvpn --mktun --dev tun0
    sudo lxc-attach -n ap4-server-$SID -- ip link set tun0 up
    sudo lxc-attach -n ap4-server-$SID -- ip addr add $IPADDR_TUN/24 dev tun0
    sudo lxc-attach -n ap4-server-$SID -- echo "export ACTIVEP4_SRC=/root/activep4" > ~/.bash_profile
done

echo "setting up arp cache..."

ADDRS_IPV4=()
ADDRS_MAC=()

for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    IP_ADDR=$(sudo lxc-attach -n ap4-server-$SID -- ifconfig eth1 | grep 'inet ' | tr -s ' ' | cut -f3 -d' ')
    HW_ADDR=$(sudo lxc-attach -n ap4-server-$SID -- ifconfig eth1 | grep 'ether' | tr -s ' ' | cut -f3 -d' ')
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
            sudo lxc-attach ap4-server-$SID -- arp -s "${ADDRS_IPV4[I]}" "${ADDRS_MAC[I]}" -i eth1
        fi
    done
done