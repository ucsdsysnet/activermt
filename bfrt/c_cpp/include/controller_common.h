#ifndef CONTROLLER_COMMON_H
#define CONTROLLER_COMMON_H

#include <bf_rt/bf_rt.hpp>
#include <bf_rt/bf_rt_info.hpp>
#include <bf_rt/bf_rt_init.hpp>
#include <bf_rt/bf_rt_common.h>
#include <assert.h>

#include <unordered_map>
#include <string>
#include <iostream>

typedef struct {
    int         opcode;
    std::string action;
    bool        conditional;
} instrset_action_t;

typedef struct {
    std::string                             basedir;
    const bfrt::BfRtInfo*                   bfrtInfo;
    std::shared_ptr<bfrt::BfRtSession>      session;
    std::unique_ptr<bfrt::BfRtTableKey>     bfrtTableKey;
    std::unique_ptr<bfrt::BfRtTableData>    bfrtTableData;
} program_context_t;

typedef struct {
    std::unordered_map<std::string, int>    ip_config;
    std::unordered_map<int, uint8_t[6]>     mac_config;
} routing_config_t;

void read_routing_configuration(program_context_t* ctxt, std::string config, routing_config_t* cfg) {

    char configpath_ip[100], configpath_mac[100], buf[100];
    sprintf(configpath_ip, "%s/config/ip_routing_%s.csv", ctxt->basedir.c_str(), config.c_str());
    sprintf(configpath_mac, "%s/config/arp_table_%s.csv", ctxt->basedir.c_str(), config.c_str());

    const char* tok = NULL;
    int tokidx = 0, port = 0;
    std::string ip_addr = NULL, mac_addr = NULL;

    FILE* fp = fopen(configpath_ip, "r");
    while(fgets(buf, 100, fp) != NULL) {
        ip_addr.clear();
        port = -1;
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(tokidx == 0) {
                ip_addr = tok;
            } else if(tokidx == 1) {
                port = atoi(tok);
            }
            tokidx++;
        }
        if(!ip_addr.empty() && port >= 0) 
            cfg->ip_config.insert({ip_addr, port});
    }
    fclose(fp);

    tokidx = 0;

    fp = fopen(configpath_mac, "r");
    while(fgets(buf, 100, fp) != NULL) {
        mac_addr.clear();
        port = -1;
        for(tok = strtok(buf, ",\n"); tok && *tok; tok = strtok(NULL, ",\n")) {
            if(tokidx == 0) {
                ip_addr = tok;
            } else if(tokidx == 1) {
                mac_addr = tok;
            } else if(tokidx == 2) {
                port = atoi(tok);
            }
            tokidx++;
        }
        if(!ip_addr.empty() && port >= 0) {
            // uint8_t mac_addr_bytes[6];
            // sscanf(mac_addr.c_str(), "%c:%c:%c:%c:%c:%c", mac_addr_bytes[0], mac_addr_bytes[1], mac_addr_bytes[2], mac_addr_bytes[3], mac_addr_bytes[4], mac_addr_bytes[5]);
            // cfg->mac_config.insert(std::make_pair(port, mac_addr_bytes));
        }
    }
    fclose(fp);
}

void read_instruction_set(const char* instruction_set_path, std::unordered_map<std::string, instrset_action_t>* instr_set) {

    std::string pnemonic, action;
    int opcode = 0, tokidx = 0;
    bool conditional;
    const char* tok;
    char buf[100];

    FILE* fp = fopen(instruction_set_path, "r");
    
    assert(fp != NULL);

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
                conditional = (atoi(tok) == 1);
            }
            tokidx++;
        }
        if(!pnemonic.empty()) {
            instrset_action_t actiondef = {opcode, action, conditional};
            instr_set->insert({pnemonic, actiondef});
            opcode++;
        }
    }
    fclose(fp);
}

#endif