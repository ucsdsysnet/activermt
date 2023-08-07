#!/bin/bash

INSTANCE=$1
DIR_PFX=results_config_6
SRC_DIR=results_config_6_v4

if [ -z "$INSTANCE" ]
then
    echo "Usage: ./validate_results.sh <instance>"
    exit 1
fi

rm -rf data/$DIR_PFX/*
cp -r data/$SRC_DIR/$INSTANCE data/$DIR_PFX/0

 ./plotter.py data/results_config_6 config/config_6.json