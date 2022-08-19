import os
#import numpy

from time import sleep

MAX_CONSTRAINTS = 8

current_allocation = []

def attempt_allocation(fid, constr):
    global current_allocation
    print(constr)

def on_malloc_request(dev_id, pipe_id, directon, parser_id, session, msg):
    global MAX_CONSTRAINTS
    global attempt_allocation
    for digest in msg:
        fid = digest['fid']
        constr = []
        for i in range(0, MAX_CONSTRAINTS):
            lb = digest['constr_lb_%d' % i]
            ub = digest['constr_ub_%d' % i]
            ms = digest['constr_ms_%d' % i]
            if lb > 0 and ub > 0 and ms  > 0:
                constr.append((lb, ub, ms))
        attempt_allocation(fid, constr)
    return 0

bfrt.active.pipe.IngressDeparser.malloc_digest.callback_register(on_malloc_request)