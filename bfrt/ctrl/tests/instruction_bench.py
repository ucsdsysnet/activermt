import os
import sys
import time

NUM_SAMPLES = 100
BASE_DIR = "/usr/local/home/rajdeepd/activep4"
NUM_STAGES = 20

# read instruction set.
instr_set = {}
with open(os.path.join(BASE_DIR, 'config', 'opcode_action_mapping.csv')) as f:
    rows = f.read().strip().splitlines()
    opcode = 0
    for row in rows:
        entry = row.split(',')
        pnemonic = entry[0]
        action = entry[1]
        is_conditional = len(entry) > 2
        condition = entry[2] == '1' if is_conditional else None
        instr_set[pnemonic] = {
            'opcode'            : opcode,
            'action'            : action,
            'is_conditional'    : is_conditional,
            'condition'         : condition
        }
        opcode += 1
    f.close()

assert(len(instr_set) > 0)

measurements = []

for i in range(0, NUM_SAMPLES):

    print("Running experiment {} ... ".format(i))

    ts_start = time.time()

    count = 0

    for stage_id in range(0, NUM_STAGES):

        stage_id_gress = int(stage_id % (NUM_STAGES / 2))

        table_name = "instruction_{}".format(stage_id_gress)
        tbl = getattr(bfrt.active.pipe.Ingress, table_name) if stage_id < (NUM_STAGES / 2)  else getattr(bfrt.active.pipe.Egress, table_name)

        tbl.clear()
        bfrt.complete_operations()

        bfrt.batch_begin()

        for pnemonic in instr_set:
            if 'VADDR_' in pnemonic or instr_set[pnemonic]['action'] == 'NULL':
                continue
            add_method = getattr(tbl, "add_with_{}".format(instr_set[pnemonic]['action'].replace('#', str(stage_id_gress))))
            add_method(
                fid_start=0, 
                fid_end=255, 
                opcode=instr_set[pnemonic]['opcode'], 
                complete=0, 
                disabled=0, 
                mbr=0, 
                mbr_p_length=(32 if instr_set[pnemonic]['is_conditional'] and not instr_set[pnemonic]['condition'] else 0), 
                mar_19_0__start=0, 
                mar_19_0__end=94207
            )
            count += 1

        bfrt.complete_operations()
        bfrt.batch_end()

    ts_end = time.time()
    ts_elapsed_ms = (ts_end - ts_start) * 1000

    measurements.append(ts_elapsed_ms)

print("Elapsed (avg) time for {} entries = {} ms".format(count, sum(measurements) / NUM_SAMPLES))

with open(os.path.join(BASE_DIR, 'bfrt', 'ctrl', 'tests', 'results.csv'), 'w') as f:
    f.write("\n".join([str(x) for x in measurements]))
    f.close()