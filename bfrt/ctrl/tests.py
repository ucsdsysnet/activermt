import os
import time

"""NUM_STAGES_IG = 10

FIDS = [1]

for fid in FIDS:
    for i in range(0, NUM_STAGES_IG):
        table = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % i)
        spec = getattr(table, 'add_with_get_allocation_s%d' % i)
        spec(fid=fid, flag_allocated=1, offset_ig=0, size_ig=0xFFFF, offset_eg=0, size_eg=0xFFFF)
    bfrt.active.pipe.Ingress.allocation.add_with_allocated(fid=fid, flag_reqalloc=2)

entries = bfrt.active.pipe.Ingress.allocation.dump(return_ents=True)

if entries is not None:
    print("Listing entries ... ")
    for entry in entries:
        if entry.key.get(b'hdr.ih.fid') == 1:
            print("Removing entry with FID 1")
            entry.remove()

entries = bfrt.active.pipe.Ingress.instruction_1.dump(return_ents=True)
for entry in entries:
    stageId = 1
    print("Opcode", entry.key.get(b'hdr.instr$%d.opcode' % stageId))
    break"""

"""tsBegin = time.time()
bfrt.active.pipe.Ingress.heap_s0.operation_register_sync()
regvals = bfrt.active.pipe.Ingress.heap_s0.dump(return_ents=True)
tsEnd = time.time()
elapsed = tsEnd - tsBegin
print("Elapsed (seconds)", elapsed)
print("Entries", len(regvals))

print("Index", regvals[0].key[b'$REGISTER_INDEX'])

key = b'Ingress.heap_s%d.f1' % 0
print("Value", regvals[0].data[key])"""

"""entries = bfrt.active.pipe.Ingress.instruction_4.dump(return_ents=True)
for entry in entries:
    fid = entry.key.get(b'hdr.meta.fid')[0]
    opcode = entry.key.get(b'hdr.instr$%d.opcode' % 4)
    if fid == 1:
        print(entry)"""

bfrt.active.pipe.Ingress.heap_s2.operation_register_sync()
regvals = bfrt.active.pipe.Ingress.heap_s2.dump(return_ents=True)
stored = 0
for obj in regvals:
    value = obj.data[b'Ingress.heap_s2.f1']
    print(value)

bfrt.complete_operations()