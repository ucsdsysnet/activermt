#!/bin/bash

NUM_APPS=$(cat config.csv | cut -f1 -d"," | uniq | wc -l)

for (( VID = 1; VID <= $NUM_APPS; VID++ ))
do
    ping -w 1 10.$VID.0.2
done