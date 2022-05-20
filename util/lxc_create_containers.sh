#!/bin/bash

SERVER_PREFIX=ap4-server-
NUM_SERVERS=4

if [ "$EUID" -ne 0 ]
then
    echo "Root privileges required (please run as sudo)"
    exit 1
fi

if [ -z "$(lsb_release -c | grep focal)" ]
then
    echo "Ubuntu focal distribution required"
    exit 1
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

for (( SID = 0; SID < $NUM_SERVERS; SID++ ))
do
    if [ -z "$(lxc-ls | grep ap4-server-$SID)" ]
    then
        echo "container $SID not present"
    else
        echo "deleting existing container ($SERVER_PREFIX$SID) ..."
        sudo lxc-stop -n $SERVER_PREFIX$SID
        sudo lxc-destroy -n $SERVER_PREFIX$SID
    fi

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

    sudo lxc-start -n ap4-server-$SID
    sudo lxc-wait -n ap4-server-$SID -s RUNNING

    sleep 10

    lxc-attach -n ap4-server-$SID -- apt-get update
    lxc-attach -n ap4-server-$SID -- apt-get install -y net-tools openvpn python python3-pip tcpdump
    lxc-attach -n ap4-server-$SID -- pip3 install --pre scapy
done