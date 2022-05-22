%{
[tools] util/hires_ping, netproxy/activep4-tun
[env-1] Two LXC containers were connected to each other via VETHs and a L2
bridge. Each container had the interface connected to the bridge and in
addition, a TUN interface. The filtering program was run over the TUN
interface.
[env-2] Two LXC containers were connected to each other via VETHs and an emulated switch. 
Each container had the interface connected to the bridge and in
addition, a TUN interface. The filtering program was run over the TUN
interface.
[env-common] The active programs that were run were of length 18
instructions (including the EOF). A total of 1000 packets were sent in each
experiment.
[metric] RTTs were recorded for each experiment.
%}

clear;
clc

FONT_SIZE=16;

data_bridge_tun_active = csvread('ping_rtt_ns_tun_bridge_active.csv') / 1E3;
data_bridge_tun_noactive = csvread('ping_rtt_ns_tun_bridge_noactive.csv') / 1E3;
data_bridge_eth_noactive = csvread('ping_rtt_ns_eth_bridge_noactive.csv') / 1E3;

data_switch_tun_active = csvread('ping_rtt_ns_tun_switch_active.csv') / 1E6;
data_switch_tun_noactive = csvread('ping_rtt_ns_tun_switch_noactive.csv') / 1E6;
data_switch_eth_noactive = csvread('ping_rtt_ns_eth_switch_noactive.csv') / 1E6;

figure

subplot(2,2,1);
cdfplot(data_bridge_tun_active);
hold on
cdfplot(data_bridge_tun_noactive);
hold on
cdfplot(data_bridge_eth_noactive);
title('ActiveP4 latency analysis (l2 bridge)');
xlabel('RTT Latency (us)');
legend('(tun, active)', '(tun, non-active)', '(eth, non-active)');
set(gca, "FontSize", FONT_SIZE);
grid on

subplot(2,2,2);
cdfplot(data_switch_tun_active);
hold on
cdfplot(data_switch_tun_noactive);
hold on
cdfplot(data_switch_eth_noactive);
title('ActiveP4 latency analysis (emulated switch)');
xlabel('RTT Latency (ms)');
legend('(tun, active)', '(tun, non-active)', '(eth, non-active)');
set(gca, "FontSize", FONT_SIZE);
grid on

subplot(2,2,3);
data_bridge_means = [ median(data_bridge_tun_active), median(data_bridge_tun_noactive), median(data_bridge_eth_noactive) ];
bar(data_bridge_means);
ylabel('Median RTT Latency (us)');
set(gca, 'xticklabel', { '(tun, active)', '(tun, non-active)', '(eth, non-active)' });
set(gca, "FontSize", FONT_SIZE);
xtickangle(45);
grid on

subplot(2,2,4);
data_switch_means = [ median(data_switch_tun_active), median(data_switch_tun_noactive), median(data_switch_eth_noactive) ];
bar(data_switch_means);
ylabel('Median RTT Latency (ms)');
set(gca, 'xticklabel', { '(tun, active)', '(tun, non-active)', '(eth, non-active)' });
set(gca, "FontSize", FONT_SIZE);
xtickangle(45);
grid on