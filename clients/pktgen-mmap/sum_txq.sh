#!/bin/bash

sudo ethtool -S ens4 | grep -E "tx[0-9]+_packets:" | awk '{print $2}' | paste -sd+ - | bc
