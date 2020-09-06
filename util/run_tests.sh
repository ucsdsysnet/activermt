#!/bin/bash

TEST_SUITE=$1

$SDE/run_p4_tests.sh --no-veth -f config/portmap.json -p prototype -t tests/$TEST_SUITE