#!/usr/bin/python3

import os
import sys
import time
import threading

from scapy.all import *

pkt = Ether() / IP()
sendp(pkt, iface="veth0", verbose=False)