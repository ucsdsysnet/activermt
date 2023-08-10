#!/bin/bash

DST_MAC=$(arp | grep 10.0.0.2 | awk '{print $3}')
# NUM_APPS=$(cat config.csv | cut -f1 -d"," | uniq | wc -l)
NUM_APPS=1

# SERVER_ID=$(($NUM_APPS + 1))

for (( VID = 1; VID <= $NUM_APPS; VID++ ))
do
    sudo ifconfig virtio_user$(($VID - 1)) 10.$VID.0.1/24
    sudo arp -s 10.$VID.0.2 $DST_MAC
done