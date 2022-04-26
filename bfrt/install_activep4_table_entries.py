import os
import sys
from netaddr import IPAddress

#print(os.getcwd())
#sys.path.insert(0, os.path.join(os.environ['ACTIVEP4_SRC'], 'bfrt', 'ptf'))

class ActiveP4Installer:

    global bfrt
    global IPAddress

    def __init__(self):
        self.p4 = bfrt.active.pipe
        self.num_stages_ingress = 10
        self.num_stages_egress = 10
        self.opcode_action = {}
        with open('bfrt/opcode_action_mapping.csv') as f:
            mapping = f.read().strip().splitlines()
            for opcode in range(0, len(mapping)):
                m = mapping[opcode].split(',')
                pnemonic = m[0]
                action = m[1]
                conditional = (bool(m[2]) if len(m) == 3 else None)
                self.opcode_action[pnemonic] = {
                    'opcode'    : opcode,
                    'action'    : action,
                    'condition' : conditional,
                    'args'      : None
                }
            f.close()

    # Taken from ICA examples
    def clear_all(self, verbose=True, batching=True):
        for table_types in (['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR'],
                            ['SELECTOR'],
                            ['ACTION_PROFILE']):
            for table in self.p4.info(return_info=True, print_info=False):
                if table['type'] in table_types:
                    if verbose:
                        print("Clearing table {:<40} ... ".
                            format(table['full_name']), end='', flush=True)
                    table['node'].clear(batch=batching)
                    if verbose:
                        print('Done')

    def installForwardingTableEntries(self, dst_port_mapping):
        ipv4_host = self.p4.Ingress.ipv4_host
        for host in dst_port_mapping:
            ipv4_host.add_with_send(dst_addr=IPAddress(host), port=dst_port_mapping[host])
        bfrt.complete_operations()
        #ipv4_host.dump(table=True)
        #info = ipv4_host.info(return_info=True, print_info=False)

    def installInstructionTableEntriesGress(self, fid, gress, num_stages):
        for i in range(0, num_stages):
            instr_table = getattr(gress, 'instruction_%d' % (i + 1))
            for a in self.opcode_action:
                act = self.opcode_action[a]
                # TODO add conditional instructions
                if act['action'] == 'NULL' or act['condition'] is not None: 
                    continue
                add_method = getattr(instr_table, 'add_with_%s' % act['action'].replace('#', str(i + 1)))
                add_method(fid=fid, opcode=act['opcode'], complete=0, disabled=0)
        bfrt.complete_operations()

    def installInstructionTableEntries(self, fid):
        self.installInstructionTableEntriesGress(fid, self.p4.Ingress, self.num_stages_ingress)
        self.installInstructionTableEntriesGress(fid, self.p4.Egress, self.num_stages_egress)

    def installInBatches(self):
        bfrt.batch_begin()
        try:
            pass
        except BfRtTableError as e:
            if e.sts == 4:
                print("Duplicate entry")
        bfrt.batch_end()

installer = ActiveP4Installer()

dst_port_mapping = {
    '10.0.0.1'  : 0,
    '10.0.0.2'  : 1
}

installer.clear_all()
installer.installForwardingTableEntries(dst_port_mapping)
installer.installInstructionTableEntries(1)