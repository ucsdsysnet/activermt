#!/bin/bash

if [ $EUID -ne 0 ]; then
    echo "ERROR: This script requires root privileges. Please, use sudo"
    exit 1
fi

#
# dummy_setup.sh
#
# Setup dummy interfaces for using with Tofino Model and PTF
#
# Usage:
#   dummy_setup.sh [nports [npipes [ndev]]]
#
# The script creates dummy interfaces for <ndev> devices, each of which has
# <npipes> pipes. The scrips sets up interfaces for <nports> in each pipe.
# By default:
#       nports=8   npipes=4  ndev=1
#
# So the scripts sets up interfaces:
#    port0..15,128..143,256..271,384..399
# Interfaces for the CPU ports are added automatically
#
# For multi-device systems, interfaces are named port_0_0, port_0_64, etc, i.e.
# the first number is the device number.
#
# if you want to cahnge that, just chenage the function iface_name()
#
# TODO:
#   -- Output ports.json based on what just has been configured
#   -- Use ports.json as the input and configure only the ports referenced there

#
# Uncomment for debugging
# set -x

# Print Tofino-Model port number, based on dev/pipe/port
function tofino_model_port_number() {
    echo "$(($1*456+$2*128+$3))"
}

# Create a name for the interface, based on dev/pipe/port AND ndev
# You can change this function as you please
function iface_name() {
    if [ $ndev -gt 1 ]; then
        echo "port_$1_$(($2*128+$3))"
    else
        echo "port$(($2*128+$3))"
    fi
    # Alternative ("native" Harlyn numbering)
    # echo "port`tofino_model_port_number $1 $2 $3`"
}

#
# Main
#
if [ $# -ge 1 ]; then 
    nports=$1; shift
else
    nports=16
fi

if [ $# -ge 1 ]; then
    npipes=$1; shift
else
    npipes=4
fi

if [ $# -ge 1 ]; then
    ndev=$1
else
    ndev=1
fi

dev_offset=456 # PORT_COUNT_PER_CHIP_MAX (might be changed later)

echo "Creating ports for $ndev ${npipes}-pipe device(s), $nports ports per pipe"

for dev in `seq 0 $((ndev-1))`; do
    for pipe in `seq 0 $((npipes-1))`; do
        for port in `seq 0 $((nports-1))`; do
            ports="$ports `iface_name $dev $pipe $port`"
        done
    done
    if [ $ndev -gt 1 ]; then 
        ports="$ports cpu_eth_${dev}_0 cpu_pcie_${dev}"
    else
        ports="$ports cpu_eth_0 cpu_pcie"
    fi
done

for port in $ports; do
    if ! ip link show $port &> /dev/null; then
        ip link add name $port type dummy &> /dev/null
    fi
    sysctl net.ipv6.conf.$port.disable_ipv6=1 &> /dev/null
    ip link set dev $port up mtu 10240
    TOE_OPTIONS="rx tx sg tso ufo gso gro lro rxvlan txvlan rxhash"
    for TOE_OPTION in $TOE_OPTIONS; do
       /sbin/ethtool --offload $port "$TOE_OPTION" off &> /dev/null
    done
done
