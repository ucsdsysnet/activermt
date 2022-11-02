#!/bin/bash

export LD_LIBRARY_PATH=$SDE/install/lib

./ap4_controller --install-dir=$SDE/install --conf-file=$SDE/install/share/p4/targets/tofino/active.conf