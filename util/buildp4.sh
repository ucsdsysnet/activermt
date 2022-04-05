#!/bin/bash

PROGNAME=$1

mkdir $SDE/p4studio/build/$PROGNAME && cd $SDE/p4studio/build/$PROGNAME
cmake $SDE/p4studio/ \
    -DCMAKE_INSTALL_PREFIX=$SDE/install \
    -DCMAKE_MODULE_PATH=$SDE/cmake \
    -DP4_NAME=$PROGNAME \
    -DP4_PATH=$SRC/$PROGNAME.p4 \
    -THRIFT-DRIVER=ON \
    -WITHPD=ON
make $PROGNAME && make install