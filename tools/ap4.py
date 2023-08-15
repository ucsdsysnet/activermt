#!/usr/bin/python3

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'include', 'python'))

from ap4common import *

if len(sys.argv) < 2:
    print('Usage: %s <program.ap4> [num_ingress_stages=10] [num_egress_stages=10]' % sys.argv[0])
    exit(0)

num_stages_ig = int(sys.argv[2]) if len(sys.argv) > 2 else 10
num_stages_eg = int(sys.argv[3]) if len(sys.argv) > 3 else 10

with open(sys.argv[1]) as f:
    print("")
    rows = f.read().strip().splitlines()
    for i in range(0, len(rows)):
        idx = rows[i].find('//')
        if idx >= 0:
            rows[i] = rows[i][0:idx].strip()
    program = [ x.split(',') for x in rows ]
    ap = ActiveProgram(program)
    ap.compileToTarget(num_stages_ig, num_stages_eg)
    print("")
    ap.printProgram()
    with open(sys.argv[1].replace('.ap4', '.apo'), 'wb') as out:
        out.write(ap.getByteCode())
        out.close()
    # with open(sys.argv[1].replace('.ap4', '.args.csv'), 'w') as out:
    #     out.write("\n".join([ ",".join([str(y) for y in x]) for x in ap.getArgumentMap() ]))
    #     out.close()
    with open(sys.argv[1].replace('.ap4', '.memidx.csv'), 'w') as out:
        memDef = ",".join([str(x) for x in ap.getMemoryAccessIndices()])
        memDef += "\n" + str(ap.iglim) + "\n"
        out.write(memDef)
        out.close()
    # with open(sys.argv[1].replace('.ap4', '.regloads.csv'), 'w') as out:
    #     data = []
    #     for x in ap.reg_load:
    #         if ap.reg_load[x] is not None:
    #             data.append("%s,%s" % (x, ap.reg_load[x][1]))
    #     out.write("\n".join(data))
    #     out.close()
    f.close()