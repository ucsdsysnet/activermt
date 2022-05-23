CC=g++

fs: flowSender.cpp
	$(CC) flowSender.cpp -o flowSender.out

fg: flowgen.cpp
	$(CC) flowgen.cpp -o flowgen.out -lpthread

pfg: pflowgen.cpp
	$(CC) pflowgen.cpp -o pflowgen.out -lpthread

fr: flowReceiver.cpp
	$(CC) flowReceiver.cpp -o flowReceiver.out

all: fs fg fr

clean:
	rm flowSender.out flowgen.out pflowgen.out flowReceiver.out
