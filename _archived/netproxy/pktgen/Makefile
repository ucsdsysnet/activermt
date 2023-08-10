CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../../headers
HEADERS = activep4.h activep4_pktgen.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: ap4gen

debug: CCFLAGS = -DDEBUG -g
debug: ap4gen

ap4gen		: ap4gen.o
	$(CC) -o ap4gen ap4gen.o -lpthread

ap4gen.o	: ap4gen.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c ap4gen.c

clean:
	rm ap4gen.o ap4gen