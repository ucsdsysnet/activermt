#ifndef PAYLOAD_PARSER_REDIS_H
#define PAYLOAD_PARSER_REDIS_H

#define MAXSTRLEN       256
#define CR              0x0d
#define LF              0x0a
#define RESP_ARRAY      '*'
#define RESP_SIMPLESTR  '+'
#define RESP_BULKSTR    '$'
#define RESP_ERROR      '-'
#define REDIS_CMD_GET   "GET"
#define REDIS_CMD_SET   "SET"

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

#endif