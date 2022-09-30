CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../../headers
HEADERS = activep4.h activep4_netutils.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: pktgen

debug: CCFLAGS = -DDEBUG -g
debug: pktgen

pktgen		: pktgen.o
	$(CC) -o pktgen pktgen.o -lpthread

pktgen.o	: pktgen.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c pktgen.c

clean:
	rm pktgen.o pktgen