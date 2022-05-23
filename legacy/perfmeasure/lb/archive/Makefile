all: 
	g++ -o bidirectional_client2 bidirectional_client2.cpp -lrt -std=c++0x  -Wall
	g++ -o bidirectional_server bidirectional_server.cpp -lrt -std=c++0x -L /usr/lib -lboost_iostreams -Wall -lpthread

clean:
	rm -f bidirectional_client2 bidirectional_server
