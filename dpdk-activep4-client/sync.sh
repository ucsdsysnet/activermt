#!/bin/bash

rsync -rtuv ./* h2:/apps/activep4-client
rsync -am --include='*.pcap' --exclude='*' h2:/apps/activep4-client/* ./
rsync -am --include='activep4_*.csv' --exclude='*' h2:/apps/activep4-client/* ./data
