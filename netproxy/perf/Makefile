CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../../headers
HEADERS = activep4.h stats.h payload_parser_resp.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: tuntap

debug: CCFLAGS = -DDEBUG -g
debug: tuntap

tuntap		: tuntap.o
	$(CC) -o tuntap tuntap.o -lpthread

tuntap.o	: tuntap.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c tuntap.c

clean:
	rm tuntap.o tuntap