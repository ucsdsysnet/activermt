#!/bin/bash

WORKDIR=$(pwd)

NUM_REPEATS=10

mkdir -p evals/allocation

for (( R = 0; R < $NUM_REPEATS; R++ ))
do
    echo "running experiment $R ..."

    # reset allocations on switch.
    cd ../../../../
    sudo util/scapy_pktgen_resetalloc.py ens4

    sleep 3

    # run experiment.
    cd $WORKDIR
    sudo ./build/active-bench 60 --lcores 1,3,5,7,9,11,13,15,17,19

    # fetch controller log.
    scp onl:~/src/activep4-p416/logs/controller/controller.log ../../../../logs/controller/controller-asic.log

    # save logs.
    mkdir -p evals/allocation/$R
    cp rte_log_active_bench.log evals/allocation/$R/
    cp ../../../../logs/controller/controller-asic.log evals/allocation/$R/
done

echo "all experiments complete."