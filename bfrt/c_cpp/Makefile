CC		= g++
CCFLAGS	= -g

HEADERS_DIR = ./include
HEADERS = utils.h common.h telemetry.h tables.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: controller

debug: CCFLAGS = -DDEBUG -g
debug: controller

controller		: controller.o
	$(CC) -o controller controller.o -L ${SDE}/install/lib/ -lpthread -lbf_switch -lbfsys -lbfutils -lclish -ldriver

controller.o	: controller.cpp $(HDR_PATHS)
	$(CC) $(CCFLAGS) -I ${SDE}/install/include/ -c controller.cpp -g

clean:
	rm controller.o controller