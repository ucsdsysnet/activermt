CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ..
HEADERS = activep4_tunnel.h activep4.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: netproxy_activeping

debug: CCFLAGS = -DDEBUG -g
debug: netproxy_activeping

netproxy_activeping		: netproxy_activeping.o
	$(CC) -o netproxy_activeping netproxy_activeping.o

netproxy_activeping.o	: netproxy_activeping.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c netproxy_activeping.c

clean:
	rm netproxy_activeping.o netproxy_activeping