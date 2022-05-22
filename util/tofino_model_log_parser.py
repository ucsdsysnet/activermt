#!/usr/bin/python3

import os
import sys
import re
import json

if len(sys.argv) < 2:
    print("Usage: %s <path_to_log_file>" % sys.argv[0])
    sys.exit(1)

def process_log(contents):
    header_varname = 'hdr'
    regex_timestamp = re.compile(':(\d\d-\d\d \d\d:\d\d:\d\d[.]\d{6}):\\s+:(0x\d+):')
    regex_ig_port = re.compile('Ingress Pkt from port (\d+)')
    regex_extracted_field = re.compile('(0x[0-9a-f]+) (I|E) (\[(([a-zA-Z0-9_.$]+)\[(\d+:\d+)\](, )?)+(POV)?\])')
    regex_fields = re.compile('(([a-zA-Z0-9_.$]+)\[(\d+:\d+)\](, )?)')
    regex_valid_hdr = re.compile('([a-zA-Z0-9_.$]+)\.\$valid is valid')
    regex_stage_id = re.compile('Stage (\d+)')
    regex_keyword = re.compile('(set)')
    processed = []
    print("Processing %d lines of log output" % len(contents))
    for c in contents:
        row = {}
        ts = regex_timestamp.match(c)
        if ts is not None:
            row['ts'] = ts.group(1)
            row['pkt_id'] = ts.group(2)
        ig_port = regex_ig_port.search(c)
        if ig_port is not None:
            ig_port = ig_port.group(1)
            row['ig_port'] = ig_port
        if 'extracted' in c:
            extracted_field = regex_extracted_field.search(c)
            if extracted_field is not None:
                groups = extracted_field.groups()
                extracted_value = groups[0]
                ig_eg_flag = groups[1]
                extracted_fields = regex_fields.findall(groups[2])
                fields = {}
                for field in extracted_fields:
                    fields[field[1]] = field[2]
                row['extract'] = {
                    'gress'     : ig_eg_flag,
                    'value'     : extracted_value,
                    'fields'    : fields
                }
        hdr_validation = regex_valid_hdr.search(c)
        if hdr_validation is not None:
            row['valid'] = hdr_validation.group(1)
        stage_id = regex_stage_id.search(c)
        if stage_id is not None:
            row['stage_id'] = stage_id.group(1)
        if len(row.keys()) > 2:
            processed.append(row)
    return processed

def write_processed_log(processed, filename):
    with open(filename, 'w') as out:
        out.write(json.dumps(processed, indent=4))
        out.close()

with open(sys.argv[1]) as f:
    contents = f.read().splitlines()
    processed = process_log(contents)
    write_processed_log(processed, "processed_log.json")
    f.close()