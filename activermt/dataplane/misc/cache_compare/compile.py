#!/usr/bin/python3

import sys

NUM_INSTANCES = 1

if len(sys.argv) > 1:
    NUM_INSTANCES = int(sys.argv[1])

REGISTER_SIZE = 32768 + 12 * 1024

# master template.
program = None
with open('cachecmp_template.p4') as f:
    program = f.read()
    f.close()

# headers.
with open('cache_template_headers.p4') as f:
    headers_template = f.read().strip()
    headers = []
    for i in range(0, NUM_INSTANCES):
        headers.append(headers_template.replace('#', str(i)))
    program = program.replace('<cache_header_definitions>', "\n\n".join(headers))
    program = program.replace('<cache_header_declarations>', "\n\t".join([ 'cache_%d_h\t\t\t\tcache_%d;' % (i, i) for i in range(0, NUM_INSTANCES) ]))
    program = program.replace('<cache_metadata>', "\n\t".join([ 'bit<32>\tkey_%d;' % i for i in range(0, NUM_INSTANCES) ]))
    f.close()

# parsers.
with open('cache_template_parsers.p4') as f:
    parsers_template = f.read().strip().replace("\n", "\n\t")
    parsers = []
    for i in range(0, NUM_INSTANCES):
        parsers.append(parsers_template.replace('#', str(i)))
    program = program.replace('<cache_parsers>', "\n\n\t".join(parsers))
    program = program.replace('<cache_parser_selectors>', "\n\t\t\t".join([ '%d\t: parse_cache_%d;' % (i, i) for i in range(0, NUM_INSTANCES) ]))
    f.close()

# alus.
with open('cache_template_alu.p4') as f:
    alu_template = f.read().strip().replace("\n", "\n\t").replace('<register_size>', str(REGISTER_SIZE))
    alus = []
    for i in range(0, NUM_INSTANCES):
        alus.append(alu_template.replace('#', str(i)))
    program = program.replace('<register_alu_actions>', "\n\t".join(alus))
    program = program.replace('<alu_control>', "\n\t\t".join([ 'if(hdr.cache_%d.isValid()) { memory_%d_read_key(); if(meta.key_%d == hdr.cache_%d.key) memory_%d_read_value(); }' % (i, i, i, i, i) for i in range(0, NUM_INSTANCES) ]))
    f.close()

# output.
with open('cachecmp.p4', 'w') as f:
    f.write(program)
    f.close()