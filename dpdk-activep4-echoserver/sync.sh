#!/bin/bash

rsync -rtuv ./* h1:/apps/activep4-echoserver
rsync -am --include='*.pcap' --exclude='*' h1:/apps/activep4-echoserver/* ./
