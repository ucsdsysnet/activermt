CC=gcc

main: comnet_pd.c
	$(CC) comnet_pd.c -o comnet -I $(SDE_INSTALL)/include/tofinopd/active_generated -I $(SDE_INSTALL)/include -L$(SDE_INSTALL)/lib/tofinopd/active_generated -lpd -L$(SDE_INSTALL)/lib -ldriver -lbfutils -lbf_switchd_lib -lbfsys

all: main

clean:
	rm comnet
