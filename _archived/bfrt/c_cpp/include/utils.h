#ifndef UTILS_H
#define UTILS_H

#include <string>
#include <cassert>
#include <regex>
#include <cassert>
#include <unordered_map>

// #include <boost/log/trivial.hpp>
// #include <boost/log/utility/setup/file.hpp>
// #include <boost/log/expressions.hpp>

#define assertm(exp, msg) assert(((void)msg, exp))

#define MAXFILESIZE 1024

/**
 * @brief Contains an instruction definition.
 * 
 */
typedef struct {
    int         opcode;
    std::string action;
    bool        conditional;
    bool        condition;
    bool        memop;
} instrset_action_t;

typedef struct {
    uint8_t             flags;
    uint8_t             opcode;
    instrset_action_t*  op;
} active_instr_t;

typedef struct {
    int             len;
    active_instr_t* code;
} active_program_t;

/**
 * @brief Reads the instruction set from a configuration file.
 * 
 * @param instruction_set_path path to instruction set mappings
 * @param instr_set the instruction set object map to store the read instructions
 */
void read_instruction_set(const char* instruction_set_path, std::unordered_map<std::string, instrset_action_t>* instr_set) {

    std::string pnemonic, action;
    int opcode = 0, tokidx = 0;
    bool conditional = false, memop, condition;
    const char* tok;
    char buf[100];

    FILE* fp = fopen(instruction_set_path, "r");
    
    assert(fp != NULL);

    std::regex re_mem("MEM_");

    while(fgets(buf, 100, fp) != NULL) {
        pnemonic.clear();
        action.clear();
        tokidx = 0;
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(tokidx == 0) {
                pnemonic = tok;
            } else if(tokidx == 1) {
                action = tok;
            } else if(tokidx == 2) {
                conditional = true;
                condition = (atoi(tok) == 1);
            }
            tokidx++;
        }
        if(!pnemonic.empty()) {
            memop = std::regex_search(pnemonic, re_mem);
            instrset_action_t actiondef = {opcode, action, conditional, condition, memop};
            instr_set->insert({pnemonic, actiondef});
            opcode++;
        }
    }
    fclose(fp);
}

void read_active_program(const char* program_path, active_program_t* program) {

    FILE* fp = fopen(program_path, "rb");

    assert(fp != NULL);

    fseek(fp, 0, SEEK_END);
    int len = ftell(fp); 
    rewind(fp);

    char fbuf[MAXFILESIZE];
    assert(fread(fbuf, len, 1, fp) > 0);
    fclose(fp);

    int codelen = len / 2;

    assert(program != NULL);

    program->len = codelen;
    program->code = (active_instr_t*)calloc(codelen, sizeof(active_instr_t));

    for(int k = 0, i = 0; k < len; k += 2, i++) {
        program->code[i].flags = fbuf[k];
        program->code[i].opcode = fbuf[k+1];
    }
}

// void init_logger(int severity_level) {
//     boost::log::add_file_log("active_controller.log");
//     boost::log::core::get()->set_filter(boost::log::trivial::severity >= severity_level);
// }

#endif