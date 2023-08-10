CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ../../../../headers
HEADERS = stats.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: redisapp

debug: CCFLAGS = -DDEBUG -g
debug: redisapp

redisapp		: redisapp.o
	$(CC) -o redisapp redisapp.o -lhiredis -lpthread

redisapp.o	: redisapp.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -I /usr/local/include/hiredis/ -c redisapp.c

clean:
	rm redisapp.o redisapp