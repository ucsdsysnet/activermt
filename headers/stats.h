#ifndef STATS_H
#define STATS_H

#define TRUE            1
#define STATS_ITVL_NS   1E9
#define MAX_SAMPLES     10000

typedef struct {
    uint64_t    count;
    uint64_t    count_alt;
    uint32_t    numSamples;
    uint64_t    reqRate[MAX_SAMPLES];
    uint64_t    reqRateAlt[MAX_SAMPLES];
    uint64_t    ts_sec[MAX_SAMPLES];
    uint64_t    ts_nsec[MAX_SAMPLES];
} stats_t;

pthread_mutex_t lock, lock_alt;

void* monitor_stats(void* argp) {

    stats_t* stats = (stats_t*) argp;
    
    struct timespec ts_start, ts_now;
    uint64_t elapsed_ns;

    printf("Starting stats monitor ... \n");

    if( clock_gettime(CLOCK_MONOTONIC, &ts_start) < 0 ) {perror("clock_gettime"); exit(1);}

    while(TRUE) {
        if( clock_gettime(CLOCK_MONOTONIC, &ts_now) < 0 ) {perror("clock_gettime"); exit(1);}
        elapsed_ns = (ts_now.tv_sec - ts_start.tv_sec) * 1E9 + (ts_now.tv_nsec - ts_start.tv_nsec);
        if(elapsed_ns >= STATS_ITVL_NS && stats->numSamples < MAX_SAMPLES) {
            memcpy(&ts_start, (char*)&ts_now, sizeof(struct timespec));
            stats->ts_sec[stats->numSamples] = ts_now.tv_sec;
            stats->ts_nsec[stats->numSamples] = ts_now.tv_nsec;
            stats->reqRateAlt[stats->numSamples] = stats->count_alt;
            stats->reqRate[stats->numSamples++] = stats->count;
            if(stats->count > 0 || stats->count_alt > 0)
                printf("[STATS] %lu / %lu counts/sec.\n", stats->count, stats->count_alt);
            pthread_mutex_lock(&lock);
            stats->count = 0;
            pthread_mutex_unlock(&lock);
            pthread_mutex_lock(&lock_alt);
            stats->count_alt = 0;
            pthread_mutex_unlock(&lock_alt);
        }
    }
}

void write_stats(stats_t* stats, char* filename) {
    int i;
    FILE *fp = fopen(filename, "w");
    if(fp == NULL) return;
    for(i = 0; i < stats->numSamples; i++) {
        fprintf(fp, "%lu,%lu,%lu,%lu\n", stats->ts_sec[i], stats->ts_nsec[i], stats->reqRate[i], stats->reqRateAlt[i]);
    }
    fclose(fp);
    printf("[STATS] %u samples written to %s.\n", stats->numSamples, filename);
}

#endif