CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../../../../headers
HEADERS = stats.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: kvapp

debug: CCFLAGS = -DDEBUG -g
debug: kvapp

kvapp		: kvapp.o
	$(CC) -o kvapp kvapp.o -lpthread

kvapp.o	: kvapp.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c kvapp.c

clean:
	rm kvapp.o kvapp