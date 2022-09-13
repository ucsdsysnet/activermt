#!/bin/bash

FID=$1

echo "running ap4gen for FID $FID"

./ap4gen eth1 10.0.0.3 00:00:00:00:00:02 10.0.0.2 ../../config/opcode_action_mapping.csv 1 $FID