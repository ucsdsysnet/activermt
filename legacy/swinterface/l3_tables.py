clear_all()

p4_pd.ipv4_host_table_add_with_send(p4_pd.ipv4_host_match_spec_t(ipv4_dstAddr=ipv4Addr_to_i32('192.168.0.1')),p4_pd.send_action_spec_t(0))