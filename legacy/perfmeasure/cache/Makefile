CC=g++

ce: cacheEndpoint.cpp
	$(CC) cacheEndpoint.cpp -o cacheEndpoint.out

cw: cacheWriter.cpp
	$(CC) cacheWriter.cpp -o cacheWriter.out

cr: cacheReader.cpp
	$(CC) cacheReader.cpp -o cacheReader.out

crb: cacheReaderBench.cpp
	$(CC) cacheReaderBench.cpp -o cacheReaderBench.out -lpthread

rw: cacheRW.cpp
	$(CC) cacheRW.cpp -o cacheRW.out -lpcap

rwr: cacheRWRepeats.cpp
	$(CC) cacheRWRepeats.cpp -o cacheRWRepeats.out -lpcap

ro: cacheRWSingle.cpp
	$(CC) cacheRWSingle.cpp -o cacheRWSingle.out -lpcap

all: ce cw cr rw ro rwr crb

clean:
	rm cacheEndpoint.out cacheWriter.out cacheReader.out cacheRWRepeats.out cacheReaderBench.out
