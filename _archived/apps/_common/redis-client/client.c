#include <stdio.h>
#include <stdlib.h>
#include <hiredis/hiredis.h>

#define REDIS_PORT  6379

int main(int argc, char** argv) {

    if(argc < 2) {
        printf("Usage: %s <address>\n", argv[0]);
        exit(1);
    }

    redisContext* context = redisConnect(argv[1], REDIS_PORT);

    if(context != NULL && context->err) {
        printf("Error: %s\n", context->errstr);
    }

    redisReply* reply;

    reply = redisCommand(context, "GET foo");
    printf("Response: %s\n", reply->str);

    freeReplyObject(reply);
    redisFree(context);

    return 0;
}