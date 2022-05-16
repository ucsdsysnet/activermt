p4 = bfrt.l2.pipe

def clear_all(verbose=True, batching=True):
    global p4
    for table_types in (['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR'],
                        ['SELECTOR'],
                        ['ACTION_PROFILE']):
        for table in p4.info(return_info=True, print_info=False):
            if table['type'] in table_types:
                if verbose:
                    print("Clearing table {:<40} ... ".
                        format(table['full_name']), end='', flush=True)
                table['node'].clear(batch=batching)
                if verbose:
                    print('Done')

clear_all()

dst_port_mapping = {}

config_path = 'config/mac_to_port.csv'

with open(config_path) as f:
    entries = f.read().splitlines()
    for row in entries:
        record = row.split(',')
        mac_addr = record[0]
        port = int(record[1])
        dst_port_mapping[mac_addr] = port
    f.close()

for dst in dst_port_mapping:
    p4.Ingress.fwd.add_with_send(dst_addr=dst, port=dst_port_mapping[dst])
bfrt.complete_operations()

p4.Ingress.fwd.dump(table=True)