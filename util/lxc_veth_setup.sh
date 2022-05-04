#!/bin/bash

LXC_PID_CLIENT=$(sudo lxc-info -pHn ap4-client)
LXC_PID_SERVER=$(sudo lxc-info -pHn ap4-server)

sudo ip link set dev veth5 netns $LXC_PID_CLIENT name eth1
sudo ip link set dev veth7 netns $LXC_PID_SERVER name eth1

sudo lxc-attach -n ap4-client -- ip link set dev eth1 up
sudo lxc-attach -n ap4-server -- ip link set dev eth1 up
sudo lxc-attach -n ap4-client -- ifconfig eth1 10.0.0.1 netmask 255.255.255.0
sudo lxc-attach -n ap4-server -- ifconfig eth1 10.0.0.2 netmask 255.255.255.0