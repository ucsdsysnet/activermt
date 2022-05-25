#!/bin/bash

if [ "$#" -eq 0 ]
then
    echo "usage: $0 <path_to_server_log>"
    exit 1
fi

LOGFILE=$1
CSVFILE=$(echo $LOGFILE | cut -f1 -d".").csv

cat $LOGFILE | cut -f5 -d" " | cut -f1 -d"]" | uniq -c | awk '{print $2","$1}' > $CSVFILE