clear;
clc

MAX_INSTANCES = 10;
MAX_MUTATIONS = 10;
NUM_ATTEMPTS = 10;

midx = [0 0 1 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0];
constr_max_stage = [0 0 7 0 0 0 20 0 0 0 0 0 0 0 0 0 0 0 0 0];
plen = 8;

X = [];
data = [];
data2 = [];
exec_time = [];
for i = 1:MAX_INSTANCES
    sumValid = 0;
    sumTotal = 0;
    sumTime = 0;
    for j = 1:NUM_ATTEMPTS
        [nValid, nTotal] = getNumValidAllocations(i, midx, constr_max_stage, plen, MAX_MUTATIONS);
        f = @() getNumValidAllocations(i, midx, constr_max_stage, plen, MAX_MUTATIONS);
        t = timeit(f);
        sumValid = sumValid + nValid;
        sumTotal = sumTotal + nTotal;
        sumTime = sumTime + t;
    end
    X = [X i];
    t = sumTime / NUM_ATTEMPTS;
    exec_time = [exec_time t];
    fracValid = (sumValid / sumTotal);
    data = [data; fracValid];
    data2 = [data2; nTotal];
    if nValid == 0
        break
    end
end

figure
yyaxis left
plot(X, data, '-x');
ylabel('Fraction of statisfiable allocations');
yyaxis right
if MAX_MUTATIONS == 0
    semilogy(X, data2, '-o');
else
    plot(X, data2, '-o');
end
ylabel('Total allocations');
grid on
title('Mutation-based allocation (inelastic cache)');
xlabel('# instances');
set(gca, 'FontSize', 16);
xticks(X);

figure
plot(X, exec_time, '-x');
xlabel('# instances');
ylabel('Execution time (seconds)');
grid on
set(gca, 'FontSize', 16);
xticks(X);