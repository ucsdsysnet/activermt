from netaddr import IPAddress

p4 = bfrt.redis.pipe

dst_port_mapping = {
    '10.0.0.1'      : 2,
    '10.0.0.2'      : 3
}

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

for dst in dst_port_mapping:
    p4.Ingress.ipv4_host.add_with_send(dst_addr=IPAddress(dst), port=dst_port_mapping[dst])
bfrt.complete_operations()

p4.Ingress.ipv4_host.dump(table=True)