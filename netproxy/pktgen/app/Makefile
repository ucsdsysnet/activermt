CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../..
HEADERS = activep4.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: activeapp

debug: CCFLAGS = -DDEBUG -g
debug: activeapp

activeapp		: activeapp.o
	$(CC) -o activeapp activeapp.o -lpthread

activeapp.o	: activeapp.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c activeapp.c

clean:
	rm activeapp.o activeapp