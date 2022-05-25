#!/bin/bash

if [ -z "$ACTIVEP4_SRC" ]
then
    echo "ACTIVEP4_SRC env variable not set"
    exit 1
fi

nohup $ACTIVEP4_SRC/netproxy/cheetahlb/netproxy_cheetahlb tun0 eth1 $ACTIVEP4_SRC/apps/cheetahlb/active > $ACTIVEP4_SRC/logs/servers/$HOSTNAME-netproxy.log &

NETPROXY_PID=$!
echo $NETPROXY_PID > $ACTIVEP4_SRC/logs/servers/netproxy.pid

echo "Network filter started with PID $NETPROXY_PID"

nohup $ACTIVEP4_SRC/apps/cheetahlb/clients/bash/http_server.sh > $ACTIVEP4_SRC/logs/servers/$HOSTNAME-httpserver.log &

HTTPSERVER_PID=$!
echo $HTTPSERVER_PID > $ACTIVEP4_SRC/logs/servers/httpserver.pid

echo "HTTP server started with PID $HTTPSERVER_PID"