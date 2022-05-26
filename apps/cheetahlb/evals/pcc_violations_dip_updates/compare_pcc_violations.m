%{
[tools] netproxy, tofino-model, http-client, http-server, dip-updater
[env] client container connected via emulator to 4 servers; bucket size of
4 was used to load balance traffic among 4 servers; dip buckets were
updated at regular intervals by permuting the buckets every interval.
[params] 1000 requests were sent to the servers.
[metric] percentage of connections that were broken when packets were
forwarded to an incorrect destination.
%}

clear;
clc

update_frequency_ms = [10 100 1000];
num_datasets = length(update_frequency_ms);

pcc_violations = zeros(num_datasets, 2);
req_rates = zeros(num_datasets, 2);
for i = 1:num_datasets
    % cheetah lb
    data = csvread(sprintf('stats_dip_updates_%dms.csv', update_frequency_ms(i)));
    req_rates(i, 1) = mean(data( : , 4));
    data = data( : , 3) * 100 ./ (data( : , 2) + data( : , 3));
    pcc_violations(i, 1) = mean(data);
    % hash lb
    data = csvread(sprintf('stats_hashlb_dip_%dms.csv', update_frequency_ms(i)));
    req_rates(i, 2) = mean(data( : , 4));
    data = data( : , 3) * 100 ./ (data( : , 2) + data( : , 3));
    pcc_violations(i, 2) = mean(data);
end

figure
yyaxis left
semilogx(update_frequency_ms, pcc_violations( : , 1), '-x');
hold on
semilogx(update_frequency_ms, pcc_violations( : , 2), '-o');
ylabel('PCC violations (%)');
ylim([-50 50]);
yyaxis right
semilogx(update_frequency_ms, req_rates( : , 1), '-x');
hold on
semilogx(update_frequency_ms, req_rates( : , 2), '-o');
ylabel('Requests/second');
ylim([0 100]);
title('PCC violations with Cheetah LB');
xlabel('DIP bucket update frequency (ms)');
legend('Cheetah LB', 'Hash-based LB');
set(gca, 'FontSize', 16);
grid on