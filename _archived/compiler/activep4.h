#ifndef ACTIVEP4_H
#define ACTIVEP4_H

#define TRUE            1
#define MAXARGS         10
#define MAXPROGLEN      50
#define MAXPROGSIZE     512
#define MAXFILESIZE     1024
#define ACTIVEP4SIG     0x12345678

#define AP4FLAGMASK_OPT_ARGS    0x8000
#define AP4FLAGMASK_OPT_DATA    0x4000
#define AP4FLAGMASK_FLAG_EOE    0x0100
#define AP4FLAGMASK_FLAG_MARKED 0x0800

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <malloc.h>

typedef struct {
    uint32_t    SIG;
    uint16_t    flags;
    uint16_t    fid;
    uint16_t    seq;
} activep4_ih;

typedef struct {
    uint32_t    data_0;
    uint32_t    data_1;
    uint32_t    data_2;
    uint32_t    data_3;
    uint32_t    data_4;
} activep4_data_t;

typedef struct {
    uint8_t     flags;
    uint8_t     opcode;
    uint16_t    arg;
} activep4_instr;

typedef struct {
    uint32_t    bulk_data_0;
    uint32_t    bulk_data_1;
    uint32_t    bulk_data_2;
    uint32_t    bulk_data_3;
    uint32_t    bulk_data_4;
    uint32_t    bulk_data_5;
    uint32_t    bulk_data_6;
    uint32_t    bulk_data_7;
    uint32_t    bulk_data_8;
    uint32_t    bulk_data_9;
    uint32_t    bulk_data_10;
    uint32_t    bulk_data_11;
    uint32_t    bulk_data_12;
    uint32_t    bulk_data_13;
    uint32_t    bulk_data_14;
    uint32_t    bulk_data_15;
    uint32_t    bulk_data_16;
    uint32_t    bulk_data_17;
} activep4_bulk_data_t;

#endif