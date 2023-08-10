#ifndef TELEMETRY_H
#define TELEMETRY_H

#include <string>
#include <iostream>
#include <fstream>

#include <sys/stat.h>

typedef struct {
    int id;
    uint64_t measurement;
} sample_t;

typedef struct {
    int num_samples;
    int idx;
    std::shared_ptr<sample_t> sample;
} experiment_t;

typedef struct {
    int num_repeats;
    int idx;
    std::shared_ptr<experiment_t> exp;
} analysis_t;

static analysis_t analysis;

void init_analysis(int num_experiments, int num_samples) {
    memset(&analysis, 0, sizeof(analysis));
    analysis.num_repeats = num_experiments;
    analysis.exp = std::shared_ptr<experiment_t>(new experiment_t[num_experiments]());
    for(int i = 0; i < analysis.num_repeats; i++) {
        analysis.exp.get()[i].num_samples = num_samples;
        analysis.exp.get()[i].sample = std::shared_ptr<sample_t>(new sample_t[num_samples]());
    }
}

void advance_experiment() {
    analysis.idx++;
}

void add_sample(int id, uint64_t measurement) {
    // printf("Adding sample %d ... \n", analysis.exp.get()[analysis.idx].idx);
    assertm(analysis.idx < analysis.num_repeats, "Number of experiments exceeded limit.\n");
    assertm(analysis.exp.get()[analysis.idx].idx < analysis.exp.get()[analysis.idx].num_samples, "Number of samples exceeded.\n");
    analysis.exp.get()[analysis.idx].sample.get()[analysis.exp.get()[analysis.idx].idx].id = (id >= 0) ? id : analysis.exp.get()[analysis.idx].idx + 1;
    analysis.exp.get()[analysis.idx].sample.get()[analysis.exp.get()[analysis.idx].idx].measurement = measurement;
    analysis.exp.get()[analysis.idx].idx++;
}

void save_results(std::string prefix) {

    mkdir("results", S_IRWXU | S_IRWXG);
    
    for(int i = 0; i < analysis.idx; i++) {
        std::ofstream fp;
        std::string filename = "results/" + prefix + "exp_" + std::to_string(i) + ".csv";
        // printf("Writing %d samples from experiment %d to file %s ... \n", analysis.exp.get()[i].idx, i, filename.c_str());
        fp.open(filename);
        for(int j = 0; j < analysis.exp.get()[i].idx; j++) {
            fp << analysis.exp.get()[i].sample.get()[j].id << "," << analysis.exp.get()[i].sample.get()[j].measurement << std::endl;
        }
        fp.close();
    }

    printf("Results saved.\n");
}

#endif