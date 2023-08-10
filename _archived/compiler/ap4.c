#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "activep4.h"

#define MNEMONIC_MAXLEN     50
#define BUFLEN              100

typedef struct {
    char    mnemonic[MNEMONIC_MAXLEN];
    char    action[MNEMONIC_MAXLEN];
    int     options;
} opcode_action_map_t;

typedef struct {
    char    mnemonic[MNEMONIC_MAXLEN];
    char    param[MNEMONIC_MAXLEN];
} active_instruction_mnemonic_t;

typedef struct {
    char    param[MNEMONIC_MAXLEN];
    int     indices[MAXPROGLEN];
    int     num_indices;
} active_param_t;

typedef struct {
    char    arg[MAXPROGLEN][MNEMONIC_MAXLEN];
    int     num_args;
} active_arguments_t;

static inline int read_opcode_action_map(char* filename, opcode_action_map_t* map) {
    int i = 0, tokidx;
    char buf[BUFLEN];
    const char* tok;
    FILE* fp = fopen(filename, "r");
    if(fp == NULL) {
        perror("fopen");
        return 0;
    }
    while(fgets(buf, BUFLEN, fp) != NULL) {
        tokidx = 0;
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(isspace(tok[0])) continue;
            if(tokidx == 0) strcpy(map[i].mnemonic, tok);
            else if(tokidx == 1) strcpy(map[i].action, tok);
            else map[i].options = atoi(tok);
            tokidx++;
        }
        i++;
    }
    fclose(fp);
    return i;
}

static inline int read_active_program(char* filename, active_instruction_mnemonic_t* mnemonics) {
    int i = 0, tokidx;
    char buf[BUFLEN];
    const char* tok;
    FILE* fp = fopen(filename, "r");
    if(fp == NULL) {
        perror("fopen");
        return 0;
    }
    while(fgets(buf, BUFLEN, fp) != NULL) {
        tokidx = 0;
        mnemonics[i].mnemonic[0] = '\0';
        mnemonics[i].param[0] = '\0';
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(isspace(tok[0])) continue;
            if(tokidx++ == 0) strcpy(mnemonics[i].mnemonic, tok);
            else strcpy(mnemonics[i].param, tok);
        }
        i++;
    }
    fclose(fp);
    return i;
}

static inline void parse_active_program(active_instruction_mnemonic_t* mnemonics, int num_instructions, activep4_instr* instr, active_arguments_t* args) {
    int i, argidx = 0, lidx = 0;
    active_param_t param_args, param_labels;
    for(i = 0; i < num_instructions; i++) {
        if(mnemonics[i].param[0] == '@') {}
        else if(mnemonics[i].param[0] == '$') {}
        else if(mnemonics[i].param[0] == ':') {}
    }
}

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("usage: %s program.ap4\n", argv[0]);
        exit(1);
    }

    active_instruction_mnemonic_t mnemonics[MAXPROGLEN];

    int program_length = read_active_program(argv[1], mnemonics);

    printf("Read %d instructions from %s.\n", program_length, argv[1]);

    return 0;
}