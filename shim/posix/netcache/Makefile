CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ..
HEADERS = activep4_tunnel.h activep4.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: netproxy_netcache

debug: CCFLAGS = -DDEBUG -g
debug: netproxy_netcache

netproxy_netcache		: netproxy_netcache.o
	$(CC) -o netproxy_netcache netproxy_netcache.o

netproxy_netcache.o	: netproxy_netcache.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c netproxy_netcache.c

clean:
	rm netproxy_netcache.o netproxy_netcache