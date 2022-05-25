#!/bin/bash

NETPROXY_PID=$(cat $ACTIVEP4_SRC/logs/servers/netproxy.pid)
HTTPSERVER_PID=$(cat $ACTIVEP4_SRC/logs/servers/httpserver.pid)

kill -9 $NETPROXY_PID
kill -9 $HTTPSERVER_PID