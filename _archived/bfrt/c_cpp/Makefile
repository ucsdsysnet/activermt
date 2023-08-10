CC		= g++
CCFLAGS	= -g

HEADERS_DIR = ./include
HEADERS = utils.h common.h telemetry.h tables.h allocator.h
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: controller

debug: CCFLAGS = -DDEBUG -g
debug: controller

controller		: controller.o
	$(CC) -o bin/controller bin/controller.o -L ${SDE}/install/lib/ -lpthread -lbf_switch -lbfsys -lbfutils -lclish -ldriver

controller.o	: controller.cpp $(HDR_PATHS)
	$(CC) -o bin/controller.o $(CCFLAGS) -I ${SDE}/install/include/ -c controller.cpp -g

bench-reconfig		: reconfig.o
	$(CC) -o bin/bench-reconfig bin/reconfig.o -L ${SDE}/install/lib/ -lpthread -lbf_switch -lbfsys -lbfutils -lclish -ldriver

reconfig.o	: bench/reconfig.cpp $(HDR_PATHS)
	$(CC) -o bin/reconfig.o $(CCFLAGS) -I ${SDE}/install/include/ -c bench/reconfig.cpp -g

bench-register-sync		: register-sync.o
	$(CC) -o bin/bench-reg-sync bin/register-sync.o -L ${SDE}/install/lib/ -lpthread -lbf_switch -lbfsys -lbfutils -lclish -ldriver

register-sync.o	: bench/register-sync.cpp
	$(CC) -o bin/register-sync.o $(CCFLAGS) -I ${SDE}/install/include/ -I ${SDE}/pkgsrc/bf-drivers/bf_switchd/bfrt_examples/ -c bench/register-sync.cpp -g

clean:
	rm bin/controller.o bin/controller