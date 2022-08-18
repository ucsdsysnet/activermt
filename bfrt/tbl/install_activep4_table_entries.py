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
        self.num_stages_ingress = 10
        self.num_stages_egress = 10
        self.recirculation_enabled = True
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
        self.sid_to_port_mapping = {}
        self.dst_port_mapping = {}
        self.ports = []

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

    def installForwardingTableEntries(self, config='ptf'):
        vport_dst_mapping = {}
        port_to_mac = {}
        with open(os.path.join(self.base_path, 'config', 'ip_routing_%s.csv' % config)) as f:
            entries = f.read().splitlines()
            for row in entries:
                record = row.split(",")
                ip_addr = record[0]
                dport = int(record[1])
                vport = record[2]
                self.dst_port_mapping[ip_addr] = dport
                if dport not in self.ports:
                    self.ports.append(dport)
                if vport != '':
                    vport_dst_mapping[int(vport)] = ip_addr
            f.close()
        with open(os.path.join(self.base_path, 'config', 'arp_table.csv')) as f:
            entries = f.read().strip().splitlines()
            for row in entries:
                record = row.split(",")
                ip_addr = record[0]
                mac_addr = record[1]
                dport = int(record[2])
                port_to_mac[dport] = mac_addr
            f.close()
        ipv4_host = self.p4.Ingress.ipv4_host
        #vroute = self.p4.Ingress.vroute
        for host in self.dst_port_mapping:
            ipv4_host.add_with_send(dst_addr=IPAddress(host), port=self.dst_port_mapping[host], mac=port_to_mac[self.dst_port_mapping[host]])
        """for vport in vport_dst_mapping:
            vroute.add_with_send(port_change=1, vport=vport, port=dst_port_mapping[vport_dst_mapping[vport]], mac=port_to_mac[dst_port_mapping[vport_dst_mapping[vport]]])"""
        bfrt.complete_operations()
        #ipv4_host.dump(table=True)
        #info = ipv4_host.info(return_info=True, print_info=False)

    def installInstructionTableEntriesGress(self, fid, gress, num_stages, offset=0):
        REG_MAX = 0xFFFFF
        for i in range(offset, num_stages + offset):
            instr_table = getattr(gress, 'instruction_%d' % i)
            for a in self.opcode_action:
                act = self.opcode_action[a]
                if act['action'] == 'NULL': 
                    continue
                add_method = getattr(instr_table, 'add_with_%s' % act['action'].replace('#', str(i)))
                add_method_skip = getattr(instr_table, 'add_with_skip')
                add_method_rejoin = getattr(instr_table, 'add_with_attempt_rejoin_s%s' % str(i))
                if act['condition'] is not None:
                    mbr_19_0__start = 1 if act['condition'] else 0
                    mbr_19_0__end = REG_MAX if act['condition'] else 0
                    add_method(fid=fid, opcode=act['opcode'], complete=0, disabled=0, mbr_19_0__start=mbr_19_0__start, mbr_19_0__end=mbr_19_0__end, mar_19_0__start=0, mar_19_0__end=REG_MAX)
                    mbr_19_0__start_default = 0 if act['condition'] else 1
                    mbr_19_0__end_default = 0 if act['condition'] else REG_MAX
                    add_method_skip(fid=fid, opcode=act['opcode'], complete=0, disabled=0, mbr_19_0__start=mbr_19_0__start_default, mbr_19_0__end=mbr_19_0__end_default, mar_19_0__start=0, mar_19_0__end=REG_MAX)
                else:
                    if act['opcode'] == 0:
                        add_method(fid=fid, opcode=act['opcode'], complete=1, disabled=0, mbr_19_0__start=0, mbr_19_0__end=REG_MAX, mar_19_0__start=0, mar_19_0__end=REG_MAX)
                    add_method(fid=fid, opcode=act['opcode'], complete=0, disabled=0, mbr_19_0__start=0, mbr_19_0__end=REG_MAX, mar_19_0__start=0, mar_19_0__end=REG_MAX)
                add_method_rejoin(fid=fid, opcode=act['opcode'], complete=0, disabled=1, mbr_19_0__start=0, mbr_19_0__end=REG_MAX, mar_19_0__start=0, mar_19_0__end=REG_MAX)
            #instr_table.dump(table=True)
        bfrt.complete_operations()

    def installInstructionTableEntries(self, fid):
        self.installInstructionTableEntriesGress(fid, self.p4.Ingress, self.num_stages_ingress)
        self.installInstructionTableEntriesGress(fid, self.p4.Egress, self.num_stages_egress)

    def addQuotas(self, fid, recirculate=False):
        #rand_thresh = math.floor(recirc_pct * 0xFFFF)
        if(recirculate):
            self.p4.Ingress.quota_recirc.add_with_enable_recirculation(fid=fid)

    def createSidToPortMapping(self):
        self.sid_to_port_mapping = {}
        sid = 0
        for port in self.ports:
            sid = sid + 1
            self.sid_to_port_mapping[sid] = port
        print(self.sid_to_port_mapping)
    
    def setMirrorSessions(self):
        if not self.recirculation_enabled:
            return
        for sid in self.sid_to_port_mapping:
            bfrt.mirror.cfg.add_with_normal(sid=sid, direction='EGRESS', session_enable=True, ucast_egress_port=self.sid_to_port_mapping[sid], ucast_egress_port_valid=1, max_pkt_len=16384)
            self.p4.Egress.mirror_cfg.add_with_set_mirror(egress_port=self.sid_to_port_mapping[sid], sessid=sid)
        bfrt.mirror.dump()

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

    """def resetTrafficCounters(self):
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
        bfrt.batch_end()"""

installer = ActiveP4Installer()

fids = [1]

installer.clear_all()
installer.installForwardingTableEntries(config='default')
installer.installInstructionTableEntries(1)
installer.createSidToPortMapping()
installer.setMirrorSessions()
installer.addQuotas(1, recirculate=True)

#installer.getTrafficCounters(fids)
#installer.resetTrafficCounters()