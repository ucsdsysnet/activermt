import os
import math
import sys
import inspect
from netaddr import IPAddress

class ActiveP4Installer:

    global os
    global bfrt
    global math
    global inspect
    global IPAddress

    def __init__(self):
        self.p4 = bfrt.active.pipe
        self.num_stages_ingress = 8
        self.num_stages_egress = 10
        self.recirculation_enabled = False
        self.base_path = "/usr/local/home/rajdeepd/activep4"
        #self.base_path = "/root/src/activep4-p416"
        self.allocations = {
            1       : {
                'memory'        : (0, 0xFFFF),
                'recirc_pct'    : 1.0,
                'recirc_circs'  : 1
            }
        }
        self.opcode_action = {}
        with open('%s/config/opcode_action_mapping.csv' % self.base_path) as f:
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

    def installForwardingTableEntries(self, dst_port_mapping, vport_dst_mapping):
        ipv4_host = self.p4.Ingress.ipv4_host
        vroute = self.p4.Ingress.vroute
        for host in dst_port_mapping:
            ipv4_host.add_with_send(dst_addr=IPAddress(host), port=dst_port_mapping[host])
        for vport in vport_dst_mapping:
            vroute.add_with_send(port_change=1, vport=vport, port=dst_port_mapping[vport_dst_mapping[vport]])
        bfrt.complete_operations()
        #ipv4_host.dump(table=True)
        #info = ipv4_host.info(return_info=True, print_info=False)

    def installInstructionTableEntriesGress(self, fid, gress, num_stages):
        for i in range(0, num_stages):
            instr_table = getattr(gress, 'instruction_%d' % i)
            for a in self.opcode_action:
                act = self.opcode_action[a]
                if act['action'] == 'NULL': 
                    continue
                add_method = getattr(instr_table, 'add_with_%s' % act['action'].replace('#', str(i)))
                add_method_rejoin = getattr(instr_table, 'add_with_attempt_rejoin_s%s' % str(i))
                if act['condition'] is not None:
                    mbr_start = 1 if act['condition'] else 0
                    mbr_end = 0xFFFF if act['condition'] else 0
                    add_method(fid=fid, opcode=act['opcode'], complete=0, disabled=0, mbr_start=mbr_start, mbr_end=mbr_end, mar_start=0, mar_end=0xFFFF)
                else:
                    if act['opcode'] == 0:
                        add_method(fid=fid, opcode=act['opcode'], complete=1, disabled=0, mbr_start=0, mbr_end=0xFFFF, mar_start=0, mar_end=0xFFFF)
                    add_method(fid=fid, opcode=act['opcode'], complete=0, disabled=0, mbr_start=0, mbr_end=0xFFFF, mar_start=0, mar_end=0xFFFF)
                add_method_rejoin(fid=fid, opcode=act['opcode'], complete=0, disabled=1, mbr_start=0, mbr_end=0xFFFF, mar_start=0, mar_end=0xFFFF)
        bfrt.complete_operations()

    def installInstructionTableEntries(self, fid):
        self.installInstructionTableEntriesGress(fid, self.p4.Ingress, self.num_stages_ingress)
        self.installInstructionTableEntriesGress(fid, self.p4.Egress, self.num_stages_egress)

    def addQuotas(self, fid, alloc_id, recirc_pct, circulations, mem_start, mem_end, curr_bw, addrmask, offset):
        rand_thresh = math.floor(recirc_pct * 0xFFFF)
        self.p4.Ingress.seq_vaddr.add_with_get_seq_vaddr_params(fid=fid, addrmask=addrmask, offset=offset)
        self.p4.Ingress.quotas.add_with_set_quotas(fid=fid, flag_reqalloc=0, randnum_start=0, randnum_end=rand_thresh, circulations=circulations)
        self.p4.Ingress.quotas.add_with_get_quotas(fid=fid, flag_reqalloc=1, randnum_start=0, randnum_end=0xFFFF, alloc_id=alloc_id, mem_start=mem_start, mem_end=mem_end, curr_bw=curr_bw)
        if self.recirculation_enabled:
            self.p4.Egress.recirculation.add_with_set_mirror(mir_sess=0)

    def setMirrorSessions(self, sid_to_port_mapping):
        if not self.recirculation_enabled:
            return
        for sid in sid_to_port_mapping:
            bfrt.mirror.cfg.add_with_normal(
                sid=sid, 
                session_enable=True, 
                direction="EGRESS", 
                ucast_egress_port=0, 
                ucast_egress_port_valid=False, 
                egress_port_queue=0, 
                ingress_cos=0, 
                packet_color=0, 
                level1_mcast_hash=0, 
                level2_mcast_hash=0, 
                mcast_grp_a=0, 
                mcast_grp_a_valid=False, 
                mcast_grp_b=0, 
                mcast_grp_b_valid=False, 
                mcast_l1_xid=0, 
                mcast_l2_xid=0, 
                mcast_rid=0, 
                icos_for_copy_to_cpu=0, 
                copy_to_cpu=False, 
                max_pkt_len=0
            )
        #bfrt.mirror.dump()

    def getTrafficCounters(self, fids):
        traffic_overall = self.p4.Ingress.overall_stats.get(0)
        traffic_by_fid = {}
        for fid in fids:
            traffic_ig = self.p4.Ingress.activep4_stats.get(fid)
            traffic_eg = self.p4.Egress.activep4_stats.get(fid)
            traffic_by_fid[fid] = {
                'ingress'   : traffic_ig,
                'egress'    : traffic_eg
            }
        return (traffic_overall, traffic_by_fid)

    def resetTrafficCounters(self):
        self.p4.Ingress.activep4_stats.clear()
        self.p4.Egress.activep4_stats.clear()
        self.p4.Ingress.overall_stats.clear()

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
    '10.0.1.1'      : 0,
    '10.0.1.2'      : 1,
    '10.0.0.1'      : 2,
    '10.0.0.2'      : 3,
    '10.0.2.1'      : 2,
    '10.0.2.2'      : 3,
    '192.168.0.1'   : 188,
    '192.168.1.1'   : 184
}

vport_dst_mapping = {
    0   : '10.0.2.2',
    1   : '10.0.2.2'
}

sid_to_port_mapping = {
    1   : 0,
    2   : 1
}

fids = [1]

installer.clear_all()
installer.installForwardingTableEntries(dst_port_mapping, vport_dst_mapping)
installer.installInstructionTableEntries(1)
installer.addQuotas(1, 1, 1.0, 1, 0, 0xFFFF, 0, 0x00FF, 0x0000)
installer.setMirrorSessions(sid_to_port_mapping)
#installer.getTrafficCounters(fids)
#installer.resetTrafficCounters()