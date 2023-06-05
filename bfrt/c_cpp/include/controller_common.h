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
#include <regex>

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

#endif