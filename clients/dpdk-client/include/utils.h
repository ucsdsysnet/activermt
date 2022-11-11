#ifndef UTILS_H
#define UTILS_H

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <ncurses.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <net/ethernet.h>
#include <rte_ethdev.h>

#include "types.h"
#include "../../../headers/activep4.h"

#define DISPLAY_BUFFER_SIZE     65536
#define MAX_DISPLAY_FIELDS      16

pthread_mutex_t buflock;

#define DISPLAY_LOG(X, ...)     pthread_mutex_lock(&buflock); buffer_offset += sprintf(display_buffer + buffer_offset, X, ##__VA_ARGS__); pthread_mutex_unlock(&buflock);

char display_buffer[DISPLAY_BUFFER_SIZE];
int buffer_offset;

typedef struct {
    char    display_field[64];
    char    display_data[128];
} display_field_t;

display_field_t display_data[MAX_DISPLAY_FIELDS];
int num_display_fields;

static inline void print_hwaddr(unsigned char* hwaddr) {
    printf("%.2x:%.2x:%.2x:%.2x:%.2x:%.2x", hwaddr[0], hwaddr[1], hwaddr[2], hwaddr[3], hwaddr[4], hwaddr[5]);
}

static inline void print_ipv4_addr(uint32_t ipv4addr) {
    char buf[100];
    inet_ntop(AF_INET, &ipv4addr, buf, 16);
    printf("%s", buf);
}

static inline void print_pktinfo(char* buf, int pktlen) {
    struct ethhdr* eth = (struct ethhdr*) buf;
    int offset = 0;
    if(ntohs(eth->h_proto) == AP4_ETHER_TYPE_AP4) {
        offset += sizeof(activep4_ih);
        if(ntohs(((activep4_ih*)&eth[1])->flags) & AP4FLAGMASK_OPT_ARGS) offset += sizeof(activep4_data_t);
        offset += get_active_eof(buf + sizeof(struct ethhdr) + offset, pktlen - offset);
    }
    struct iphdr* iph = (struct iphdr*) (buf + sizeof(struct ethhdr) + offset);
    printf("[0x%x] [", ntohs(eth->h_proto));
    print_ipv4_addr(iph->saddr);
    printf(" -> ");
    print_ipv4_addr(iph->daddr);
    printf("] [");
    print_hwaddr(eth->h_source);
    printf(" -> ");
    print_hwaddr(eth->h_dest);
    printf("]\n");
}

static inline void initialize_display() {
    memset(display_buffer, 0, DISPLAY_BUFFER_SIZE);
    buffer_offset = 0;
    num_display_fields = 0;
    initscr();
}

static inline void display_append(char* buf) {
    pthread_mutex_lock(&buflock);
    strcpy(display_buffer + buffer_offset, buf);
    buffer_offset += strlen(buf);
    if(buffer_offset >= DISPLAY_BUFFER_SIZE)
        display_buffer[DISPLAY_BUFFER_SIZE - 1] = '\0';
    pthread_mutex_unlock(&buflock);
}

static inline void update_display_field(char* fieldname, char* data) {
    for(int i = 0; i < num_display_fields; i++) {
        if(strcmp(display_data[i].display_field, fieldname) == 0) {
            strcpy(display_data[i].display_data, data);
            return;
        }
    }
    if(num_display_fields >= MAX_DISPLAY_FIELDS) return;
    strcpy(display_data[num_display_fields].display_field, fieldname);
    strcpy(display_data[num_display_fields].display_data, data);
    num_display_fields++;
}

static inline void update_screen_info() {
    move(0, 0);
    char screenbuf[DISPLAY_BUFFER_SIZE];
    memset(screenbuf, 0, DISPLAY_BUFFER_SIZE);
    memcpy(screenbuf, display_buffer, buffer_offset);
    int offset = buffer_offset;
    for(int i = 0; i < num_display_fields; i++)
        offset += sprintf(screenbuf + offset, "[%s]\t\t%s\n", display_data[i].display_field, display_data[i].display_data);
    printw(screenbuf);
    refresh();
}

#endif