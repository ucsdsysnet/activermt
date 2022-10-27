CC		= g++
CCFLAGS	= -g

HEADERS_DIR = ../../headers
HEADERS = 
HDR_PATHS = $(addprefix $(HEADERS_DIR)/, $(HEADERS))

all: ap4_controller

debug: CCFLAGS = -DDEBUG -g
debug: ap4_controller

ap4_controller		: ap4_controller.o
	$(CC) -o ap4_controller ap4_controller.o -L ../../sde/install/lib/ -lpthread -lbf_switch -lbfsys -lbfutils -lclish -ldriver

ap4_controller.o	: ap4_controller.cpp $(HDR_PATHS)
	$(CC) $(CCFLAGS) -I ../../sde/install/include/ -I ${SDE}/pkgsrc/bf-drivers/bf_switchd/bfrt_examples/ -c ap4_controller.cpp -g

clean:
	rm ap4_controller.o ap4_controller