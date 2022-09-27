#ifndef STATS_H
#define STATS_H

#define STATS_ITVL_NS   1E9
#define MAX_SAMPLES     10000

typedef struct {
    uint32_t    count;
    uint32_t    numSamples;
    uint32_t    reqRate[MAX_SAMPLES];
    uint64_t    ts_sec[MAX_SAMPLES];
    uint64_t    ts_nsec[MAX_SAMPLES];
} stats_t;

pthread_mutex_t lock;

void* monitor_stats(void* argp) {

    stats_t* stats = (stats_t*) argp;
    
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}

    while(TRUE) {
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        if(elapsed_ns >= STATS_ITVL_NS && stats->numSamples < MAX_SAMPLES) {
            memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));
            stats->ts_sec[stats->numSamples] = ts_now.tv_sec;
            stats->ts_nsec[stats->numSamples] = ts_now.tv_nsec;
            stats->reqRate[stats->numSamples++] = stats->count;
            if(stats->count > 0)
                printf("[STATS] %u pkts/sec.\n", stats->count);
            pthread_mutex_lock(&lock);
            stats->count = 0;
            pthread_mutex_unlock(&lock);
        }
    }
}

void write_stats(stats_t* stats, char* filename) {
    int i;
    FILE *fp = fopen(filename, "w");
    if(fp == NULL) return;
    for(i = 0; i < stats->numSamples; i++) {
        fprintf(fp, "%lu,%lu,%u\n", stats->ts_sec[i], stats->ts_nsec[i], stats->reqRate[i]);
    }
    fclose(fp);
    printf("[STATS] %u samples written to %s.\n", stats->numSamples, filename);
}

#endif