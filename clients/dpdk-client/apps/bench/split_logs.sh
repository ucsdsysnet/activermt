#!/bin/bash

NUM_REPEATS=10

for (( R = 1; R < $NUM_REPEATS; R++ ))
do
    echo "processing log $R ... "
    diff evals/allocation/$(($R - 1))/controller-asic.log evals/allocation/$R/controller-asic.log > evals/allocation/$R/controller-asic-diff.log
done