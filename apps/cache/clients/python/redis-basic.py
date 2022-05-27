#!/usr/bin/python3

import os
import sys
import argparse
import redis

parser = argparse.ArgumentParser(description="GET/SET Key-Value objects using a Redis store.")
parser.add_argument("-p", dest="port", type=int, default=6379, help="Redis server port")
parser.add_argument("-c", dest="host", required=True, help="Hostname (IP address) of Redis server")
parser.add_argument("-s", dest="set", nargs=2, default=None, help="key value (SET key=value)")
parser.add_argument("-g", dest="get", default=None, help="key (GET key)")

args = parser.parse_args()

r = redis.Redis(host=args.host, port=args.port)

if args.set is None and args.get is None:
    parser.print_help()
    sys.exit(1)

if args.set is not None:
    r.set(args.set[0], args.set[1])

if args.get is not None:
    value = r.get(args.get)
    print(value)