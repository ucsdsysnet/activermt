#!/usr/bin/bash

DIRNAME=results_config_6

mkdir $DIRNAME

DIRS=$(ls | grep "results_config_6_")
IDX=0
for dir in $DIRS; do
    cp -r $dir/0 $DIRNAME/$IDX
    IDX=$((IDX+1))
done