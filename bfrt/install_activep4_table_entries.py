from netaddr import IPAddress

class ActiveP4Installer:

    global bfrt
    global IPAddress

    def __init__(self):
        self.p4 = bfrt.active.pipe

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

    def installTableEntries(self):
        ipv4_host = self.p4.Ingress.ipv4_host
        ipv4_host.add_with_send(dst_addr=IPAddress('192.168.1.1'),   port=1)
        ipv4_lpm =  self.p4.Ingress.ipv4_lpm
        ipv4_lpm.add_with_send(
            dst_addr=IPAddress('192.168.1.0'), dst_addr_p_length=24, port=1)
        bfrt.complete_operations()
        ipv4_host.dump(table=True)
        ipv4_lpm.dump(table=True)
        info = ipv4_host.info(return_info=True, print_info=False)

    def installInBatches(self):
        bfrt.batch_begin()
        try:
            pass
        except BfRtTableError as e:
            if e.sts == 4:
                print("Duplicate entry")
        bfrt.batch_end()

installer = ActiveP4Installer()

installer.installTableEntries()