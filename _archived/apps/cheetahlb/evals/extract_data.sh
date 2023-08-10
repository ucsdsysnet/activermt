#!/bin/bash

LOGS=$(ls ap4-server-*.log)

for LOGFILE in $LOGS
do
    CSVFILE=$(echo $LOGFILE | cut -f1 -d".").csv
    cat $LOGFILE | cut -f5 -d" " | cut -f1 -d"]" | uniq -c | awk '{print $2","$1}' > $CSVFILE
done