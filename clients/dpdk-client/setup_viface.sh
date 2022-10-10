#!/bin/bash

DST_MAC=$(arp | grep 10.0.0.2 | awk '{print $3}')

sudo ifconfig virtio_user0 10.1.0.1/24
sudo arp -s 10.1.0.2 $DST_MAC
