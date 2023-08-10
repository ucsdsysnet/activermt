#!/bin/bash

WORKDIR=$(pwd)

NUM_REPEATS=10

for (( R = 0; R < $NUM_REPEATS; R++ ))
do
    echo "processing log $R ... "
    cd evals/allocation/$R
    ../../../parse_logs.py
    ../../../parse_controller_log.py
    cd $WORKDIR
done