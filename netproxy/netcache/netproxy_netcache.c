#include <string.h>
#include <stdlib.h>

#include "../activep4_tunnel.h"

#define MAXSTRLEN       256
#define MAXFILENAME     128
#define MAXCONN         0xFFFF
#define UINT16_LEN      2
#define CR              0x0d
#define LF              0x0a
#define RESP_ARRAY      '*'
#define RESP_SIMPLESTR  '+'
#define RESP_BULKSTR    '$'
#define RESP_ERROR      '-'
#define REDIS_CMD_GET   "GET"
#define REDIS_CMD_SET   "SET"

#define UINT16_BTOI(B)  (uint16_t)((B[0] << 8) + B[1])     

typedef struct {
    int         cmd_get;
    int         cmd_set;
    int         key_len;
    int         val_len;
    char        key[MAXSTRLEN];
    char        value[MAXSTRLEN];
    char        response[MAXSTRLEN];
    char        error[MAXSTRLEN];
} redis_command_t;

typedef struct {
    uint16_t    sw_key;
    uint16_t    sw_value;
    uint16_t    addr;
} redis_ap4_kv_t;

activep4_t      ap4_read, ap4_write;
redis_ap4_kv_t  app[MAXCONN];

static inline int extract_decimal(char* buf, int* i) {
    int num = 0;
    while( buf[*i] >= 48 && buf[*i] < 58 ) num = (num * 10) + (int)buf[(*i)++] - 48;
    if(buf[*i] == CR && buf[*i + 1] == LF) *i += 2;
    return num;
}

static inline int extract_string(char* buf, int* i, char* str, int str_len) {
    int j = 0;
    if(str_len > 0) {
        while(j < str_len) str[j++] = buf[(*i)++];
    } else {
        while(buf[*i] != CR) str[j++] = buf[(*i)++];
    }
    str[j] = '\0';
    if(buf[*i] == CR && buf[*i + 1] == LF) *i += 2;
    return j;
}

static inline void deserialize_redis_data(char* buf, int buflen, redis_command_t* redis) {
    int i = 0, num, digit;
    int arr_len, str_len;
    char str[MAXSTRLEN];
    uint16_t* next_short;
    redis->cmd_get = 0;
    redis->cmd_set = 0;
    redis->key[0] = '\0';
    redis->value[0] = '\0';
    redis->response[0] = '\0';
    while(i < buflen) {
        switch(buf[i]) {
            case RESP_ARRAY:
                i++;
                arr_len = extract_decimal(buf, &i);
                break;
            case RESP_BULKSTR:
                i++;
                str_len = extract_decimal(buf, &i);
                extract_string(buf, &i, str, str_len);
                if(strcmp(str, REDIS_CMD_GET) == 0) redis->cmd_get = 1;
                else if(strcmp(str, REDIS_CMD_SET) == 0) redis->cmd_set = 1;
                else if(redis->cmd_get == 1 && arr_len == 1) {
                    memcpy(redis->key, str, str_len + 1);
                    redis->key_len = str_len;
                } else if(redis->cmd_set == 1 && arr_len == 2) {
                    memcpy(redis->key, str, str_len + 1);
                    redis->key_len = str_len;
                } else if(redis->cmd_set == 1) {
                    memcpy(redis->value, str, str_len + 1);
                    redis->val_len = str_len;
                } else {
                    memcpy(redis->response, str, str_len + 1);
                    redis->cmd_get = 1;
                }
                arr_len--;
                break;
            case RESP_ERROR:
                i++;
                str_len = extract_string(buf, &i, str, 0);
                memcpy(redis->error, str, str_len + 1);
                #ifdef DEBUG
                printf("Redis server returned error: %s\n", str);
                #endif
            case RESP_SIMPLESTR:
                i++;
                str_len = extract_string(buf, &i, str, 0);
                memcpy(redis->response, str, str_len + 1);
                redis->cmd_set = 1;
            default:
                i++;
                break;
        }
    }
}

static inline uint16_t get_object_address(redis_command_t* redis, activep4_t* ap4) {
    uint16_t addr = 0, i = 0;
    char addrbuf[UINT16_LEN];
    int boff = redis->key_len / UINT16_LEN;
    while(i < UINT16_LEN) {
        addrbuf[i] = redis->key[i * boff];
        i++;
    }
    addr = UINT16_BTOI(addrbuf);
    addr = addr & ap4->addr_mask + ap4->addr_offset;
    return addr;
}

int active_filter_udp_tx(struct iphdr* iph, struct udphdr* udph, char* buf, char* payload) { return 0; }
void active_filter_udp_rx(struct iphdr* iph, struct udphdr* udph, activep4_ih* ap4ih) {}

int active_filter_tcp_tx(struct iphdr* iph, struct tcphdr* tcph, char* buf, char* payload) {
    
    int numargs, offset = 0;
    uint16_t addr = 0, conn_id;
    redis_command_t redis;

    if(tcph->psh == 1) {
        // contains data
        inet_5tuple_t conn = {
            iph->saddr,
            iph->daddr,
            iph->protocol,
            tcph->source,
            tcph->dest
        };
        conn_id = cksum_5tuple(&conn);
        #ifdef DEBUG
        printf("TCP PUSH TX (conn %d)\n", conn_id);
        #endif
        deserialize_redis_data(payload, ntohs(iph->tot_len) - (iph->ihl * 4) - (tcph->doff * 4), &redis);
        if(redis.cmd_get == 1) {
            if(redis.response[0] == '\0') {
                // towards server
                addr = get_object_address(&redis, &ap4_read);
                #ifdef DEBUG
                printf("[SW] Key address: %hu\n", addr);
                #endif
                activep4_argval args[] = {
                    {"ADDR", addr},
                    {"KEY", UINT16_BTOI(redis.key)}
                };
                numargs = 2;
                offset = insert_active_program(buf, &ap4_read, args, numargs);
                ((activep4_ih*)buf)->acc = UINT16_BTOI(redis.key);
                ((activep4_ih*)buf)->acc2 = addr;
            } else {
                // towards client
                addr = app[conn_id].addr;
                #ifdef DEBUG
                printf("[SW] Key address: %hu\n", addr);
                #endif
                activep4_argval args[] = {
                    {"ADDR", addr},
                    {"KEY", app[conn_id].sw_key},
                    {"VALUE", UINT16_BTOI(redis.response)}
                };
                numargs = 3;
                offset = insert_active_program(buf, &ap4_write, args, numargs);
            }
        }
        #ifdef DEBUG
        printf("CMD: %s\n", ((redis.cmd_get == 1) ? REDIS_CMD_GET : ((redis.cmd_set == 1) ? REDIS_CMD_SET : "UNKNOWN")));
        printf("Key: %s\n", redis.key);
        printf("Value: %s\n", redis.value);
        printf("Response: %s\n", redis.response);
        #endif
    } else {
        offset = insert_active_initial_header(buf, ap4_read.fid, AP4FLAGS_DONE);
    }

    return offset;
}

void active_filter_tcp_rx(struct iphdr* iph, struct tcphdr* tcph, activep4_ih* ap4ih) {
    uint16_t conn_id;
    if(tcph->psh == 1) {
        inet_5tuple_t conn = {
            iph->saddr,
            iph->daddr,
            iph->protocol,
            tcph->source,
            tcph->dest
        };
        conn_id = cksum_5tuple(&conn);
        #ifdef DEBUG
        printf("TCP PUSH RX (conn %d)\n", conn_id);
        #endif
        app[conn_id].sw_key = ap4ih->acc;
        app[conn_id].addr = ap4ih->acc2;
    }
}

int main(int argc, char** argv) {

    if(argc < 4) {
        printf("usage: %s <tun_iface> <eth_iface> <active_program_dir> [fid=1]\n", argv[0]);
        exit(1);
    }

    char ap4_read_bytecode_file[MAXFILENAME], ap4_read_args_file[MAXFILENAME];
    char ap4_write_bytecode_file[MAXFILENAME], ap4_write_args_file[MAXFILENAME];

    sprintf(ap4_read_bytecode_file, "%s/cacheread.apo", argv[3]);
    sprintf(ap4_read_args_file, "%s/cacheread.args.csv", argv[3]);
    sprintf(ap4_write_bytecode_file, "%s/cachewrite.apo", argv[3]);
    sprintf(ap4_write_args_file, "%s/cachewrite.args.csv", argv[3]);

    read_active_program(&ap4_read, ap4_read_bytecode_file);
    read_active_args(&ap4_read, ap4_read_args_file);
    read_active_program(&ap4_write, ap4_write_bytecode_file);
    read_active_args(&ap4_write, ap4_write_args_file);

    ap4_read.fid = (argc > 4) ? atoi(argv[4]) : 1;
    ap4_write.fid = ap4_read.fid;

    ap4_read.addr_mask = 0xFFFF;
    ap4_read.addr_offset = 0;
    ap4_write.addr_mask = 0xFFFF;
    ap4_write.addr_offset = 0;

    printf("running active tunnel...\n");

    run_tunnel(argv[1], argv[2]);

    return 0;
}