%{
[tools] util/hires_ping, netproxy/activep4-tun
[env] Two LXC containers were connected to each other via VETHs and a L2
bridge. Each container had the interface connected to the bridge and in
addition, a TUN interface. The filtering program was run over the TUN
interface.
[control] experiment: 1000 UDP pings were directly sent to the corresponding server over
the regular interface (connected to a L2 bridge).
[treatment] experiment: 1000 UDP pings were sent to the corresponding
server via the tun interface (and then relayed through the regular
interface).
[metric] RTTs were recorded for each experiment.
%}

clear;
clc

data_control_us = csvread('ping_rtt_ns_no_tun.csv') / 1E3;
data_treatment_us = csvread('ping_rtt_ns_with_tun.csv') / 1E3;

figure
cdfplot(data_control_us);
hold on
cdfplot(data_treatment_us);

title('TUN overhead (active header insertion)');
xlabel('RTT Latency (us)');
set(gca, "FontSize", 16);
