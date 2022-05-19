CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ..
HEADERS = activep4_tunnel.h activep4.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: netproxy_cheetahlb

debug: CCFLAGS = -DDEBUG -g
debug: netproxy_cheetahlb

netproxy_cheetahlb		: netproxy_cheetahlb.o
	$(CC) -o netproxy_cheetahlb netproxy_cheetahlb.o

netproxy_cheetahlb.o	: netproxy_cheetahlb.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c netproxy_cheetahlb.c

clean:
	rm netproxy_cheetahlb.o netproxy_cheetahlb