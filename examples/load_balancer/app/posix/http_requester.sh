#!/bin/bash

NUM_REQUESTS=10
URL=http://10.1.0.2:8000/

if [ "$#" -gt 0 ]
then
    echo "Setting number of requests to $1"
    NUM_REQUESTS=$1
fi

for (( I = 0; I < $NUM_REQUESTS; I++ ))
do
    curl $URL -o /dev/null
done

echo "Sent $NUM_REQUESTS HTTP requests."