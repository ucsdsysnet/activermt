CC		= gcc
CCFLAGS	= -g

HEADERS_DIR = .
HEADERS = activep4.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: ap4c

debug: CCFLAGS = -DDEBUG -g
debug: ap4c

ap4c		: ap4.o
	$(CC) -o ap4c ap4.o

ap4.o	: ap4.c $(HDR_PATHS)
	$(CC) $(CCFLAGS) -c ap4.c

clean:
	rm ap4.o ap4c