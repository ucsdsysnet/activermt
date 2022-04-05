#!/bin/bash

rsync -rtuv --exclude '*.pyc' r4das@trolley.sysnet.ucsd.edu:~/activep4/* ./
