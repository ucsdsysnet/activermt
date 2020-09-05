#!/bin/bash

cp -r $SDE/build/p4-build/active_generated/tofino/active_generated/graphs ./
cp -r $SDE/build/p4-build/active_generated/tofino/active_generated/visualization ./
cp -r $SDE/build/p4-build/active_generated/tofino/active_generated/logs ./

#$SDE/install/bin/p4-graphs -D__TARGET_TOFINO__ -I$SDE_INSTALL/share/p4_lib --primitives $SDE/install/share/p4_lib/tofino/primitives.json --gen-dir ./graphs active.p4