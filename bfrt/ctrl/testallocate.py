import os

NUM_STAGES_IG = 10

FIDS = [1]

for fid in FIDS:
    """for i in range(0, NUM_STAGES_IG):
        table = getattr(bfrt.active.pipe.Ingress, 'allocation_%d' % i)
        spec = getattr(table, 'add_with_get_allocation_s%d' % i)
        spec(fid=fid, flag_allocated=1, offset_ig=0, size_ig=0xFFFF, offset_eg=0, size_eg=0xFFFF)"""
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
    break

bfrt.complete_operations()