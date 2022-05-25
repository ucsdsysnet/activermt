#!/usr/bin/python3

import requests
import threading
import argparse
import time
import sys

parser = argparse.ArgumentParser(description="Send HTTP requests (in parallel).")
parser.add_argument("-u", dest="url", required=True, help="URL to send HTTP GET requests to.")
parser.add_argument("-t", dest="timeout", type=int, default=2, help="Timeout (in seconds) for HTTP requests.")
parser.add_argument("-n", dest="count", type=int, default=100, help="Number of requests (per thread).")
parser.add_argument("-p", dest="threads", type=int, default=1, help="Number of threads to run in parallel.")

args = parser.parse_args()

def send_http_requests(thread_id, args):
    print("(T%d) Sending %d requests to %s..." % (thread_id, args.count, args.url))
    sum_elapsed = 0
    num_complete = 0
    ts_then = time.time()
    req_rate = 0
    for i in range(0, args.count):
        ts_start = time.time()
        try:
            response = requests.get(args.url, timeout=args.timeout)
        except:
            continue
        ts_end = time.time()
        elapsed = ts_end - ts_start
        sum_elapsed = sum_elapsed + elapsed
        num_complete = num_complete + 1
        req_rate = req_rate + 1
        elapsed_sec = ts_end - ts_then
        if elapsed_sec >= 1:
            print("[STATS] (T%d) %d requests/sec." % (thread_id, req_rate))
            req_rate = 0
            ts_then = time.time()
        if response.status_code != 200:
            print("(T%d) HTTP response: %d" % (thread_id, response.status_code))
    avg_elapsed = sum_elapsed / num_complete if num_complete > 0 else 0
    print("[STATS] (T%d) completed %d/%d requests (avg time %f seconds)." % (thread_id, num_complete, args.count, avg_elapsed))

threads = []
for i in range(0, args.threads):
    th = threading.Thread(target=send_http_requests, args=(i, args,))
    threads.append(th)
    th.start()

for th in threads:
    th.join()