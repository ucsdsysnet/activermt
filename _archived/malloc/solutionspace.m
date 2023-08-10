clear;
clc

NUM_STAGES = 5;
NUM_INSTANCES = 2;
DEMAND = 2;

% demand = 2;
% midx = [0 0 1 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0];
% constrMaxStage = [0 0 20 0 0 0 20 0 0 0 0 0 0 0 0 0 0 0 0 0];
% plen = 8;
% mutants = generateMutants(plen, midx, constrMaxStage);

NUM_ALLOCATIONS = 2^NUM_STAGES;
MAXCOST = NUM_STAGES * NUM_INSTANCES;

% set of possible allocations of two programs w/ feasibility.
Y = zeros(NUM_ALLOCATIONS^2, 1);
x0 = [1 1 0 0 0];
C = [];
X = [];
for x1 = 1:NUM_ALLOCATIONS
    for x2 = 1:NUM_ALLOCATIONS
        i = (x1 - 1) * NUM_ALLOCATIONS + x2;
        a1 = bitget(x1, NUM_STAGES:-1:1);
        a2 = bitget(x2, NUM_STAGES:-1:1);
        s1 = sum(a1);
        s2 = sum(a2);
        s = [s1 s2];
        c = sum(bitand(a1, a2));
        if all(s < 2) || c > 0
            Y(i) = MAXCOST;
        else
            cost = sum(bitand(x0, a1));
            Y(i) = cost;
            X = [X i];
            C = [C cost];
        end
    end
end

figure
% plot(1:length(Y), Y);
subplot(2, 1, 1);
scatter(X, C, 3);
title('Feasibility Region (allocations)');
xlabel('Allocation (encoded as integer)');
ylabel('Cost of allocation (# relocations)');
grid on

mutants = generateMutants(2, [1 1 0 0 0], [NUM_STAGES NUM_STAGES 0 0 0]);
nmutants = size(mutants, 2);
X = [];
Y = [];
for i = 1:nmutants
    for j = 1:nmutants
        x = (i - 1) * nmutants + j;
        cost = sum(bitand(mutants( : , i)', [1 1 0 0 0]));
        feasible = sum(bitand(mutants( : , i), mutants( : , j)));
        if feasible == 0
            X = [X x];
            Y = [Y cost];
        end
    end
end

subplot(2, 1, 2);
scatter(X, Y, 3);
title('Feasibility Region (mutants)');
xlabel('Allocation (encoded as integer)');
ylabel('Cost of allocation (# relocations)');
grid on