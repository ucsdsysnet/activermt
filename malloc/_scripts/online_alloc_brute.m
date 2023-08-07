clear;
clc

progLen = 12;
memAccessIdx = [3 6 9];
currentAllocation = [4 6 9];
NUM_STAGES = 20;

constrLB = memAccessIdx;
constrUB = constrLB + (NUM_STAGES - progLen);
numAccesses = length(constrLB);
A = zeros(numAccesses);
A(1, 1) = 1;
for r = 2:numAccesses
    A(r, r - 1) = -1;
    A(r, r) = 1;
end
constrDelta = A * constrLB';
A = -A;

x0 = memAccessIdx';
b = -constrDelta;
current = zeros(1, NUM_STAGES);
current(currentAllocation) = 1;
allocation = zeros(1, NUM_STAGES);
f = @(x) 6 - length(unique([currentAllocation'; x]));
% dot(current(x), allocation(x));

x = fmincon(f, x0, A, b, [], [], constrLB', constrUB');

% maxInstances = 20;
% for i = 1:maxInstances
%     [minOverlaps, memIdx, numTrials] = onlineAllocationBrute(progLen, memAccessIdx, currentAllocation);
%     currentAllocation = sort([currentAllocation, memIdx']);
% end