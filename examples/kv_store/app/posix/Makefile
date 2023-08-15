CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../../../../include/c/common
HEADERS = stats.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: kvapp

debug: CCFLAGS = -DDEBUG -g
debug: kvapp

kvapp		: kvapp.o | build
	$(CC) -o build/kvapp build/kvapp.o -lpthread

kvapp.o	: kvapp.c $(HDR_PATHS) | build
	$(CC) $(CCFLAGS) -o build/kvapp.o -c kvapp.c

build:
	@mkdir -p $@

clean:
	rm build/kvapp.o build/kvapp
