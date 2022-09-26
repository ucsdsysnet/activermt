CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = ..
HEADERS = activep4.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: tuntap

debug: CCFLAGS = -DDEBUG -g
debug: tuntap

tuntap		: tuntap.o
	$(CC) -o tuntap tuntap.o

tuntap.o	: tuntap.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c tuntap.c

clean:
	rm tuntap.o tuntap