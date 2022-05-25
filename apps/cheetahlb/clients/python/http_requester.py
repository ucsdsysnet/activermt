#!/usr/bin/python3

import requests
import time
import sys

server_url = "http://10.0.2.2:8000/"
num_requests = 100 if len(sys.argv) < 2 else int(sys.argv[1])

print("Sending %d requests..." % num_requests)

sum_elapsed = 0
for i in range(0, num_requests):
    ts_start = time.time()
    response = requests.get(server_url)
    ts_end = time.time()
    elapsed = ts_end - ts_start
    sum_elapsed = sum_elapsed + elapsed
    if response.status_code != 200:
        print("HTTP response: %d" % response.status_code)

avg_elapsed = sum_elapsed / num_requests

print("Completed %d requests (avg time %f seconds)." % (num_requests, avg_elapsed))