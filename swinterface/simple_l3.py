#
# Simple table setup script for simple_l3.p4
#

clear_all()

# ipv4_host
p4_pd.ipv4_host_table_add_with_send(
    p4_pd.ipv4_host_match_spec_t(ipv4Addr_to_i32("192.168.0.1")),
    p4_pd.send_action_spec_t(188))

p4_pd.ipv4_host_table_add_with_send(
    p4_pd.ipv4_host_match_spec_t(ipv4Addr_to_i32("192.168.1.1")),
    p4_pd.send_action_spec_t(184))

p4_pd.ipv4_host_table_add_with_discard(
    p4_pd.ipv4_host_match_spec_t(ipv4Addr_to_i32("192.168.1.3")))

# ipv4_lpm
p4_pd.ipv4_lpm_table_add_with_send(
    p4_pd.ipv4_lpm_match_spec_t(ipv4Addr_to_i32("192.168.1.0"), 24),
    p4_pd.send_action_spec_t(64))

p4_pd.ipv4_lpm_table_add_with_discard(
    p4_pd.ipv4_lpm_match_spec_t(ipv4Addr_to_i32("192.168.0.0"), 16))

p4_pd.ipv4_lpm_table_add_with_send(
    p4_pd.ipv4_lpm_match_spec_t(ipv4Addr_to_i32("0.0.0.0"), 0),
    p4_pd.send_action_spec_t(64))

conn_mgr.complete_operations()
