clear;
clc

NUM_STAGES = 20;

% ANALYSIS = 'complexity_local_optimum_enumeration';
% 
% Y = zeros(1, NUM_STAGES);
% for i = 1:NUM_STAGES
%     Y(i) = (i + 1)^(NUM_STAGES - i);
% end
% 
% semilogy(1:NUM_STAGES, Y, '-x');
% xlim([1 NUM_STAGES]);
% title('Enumeration complexity vs program/memory-access size');
% xlabel('# memory accesses = size of program');
% ylabel('# possible allocations');
% set(gca, 'FontSize', 16);
% saveas(gcf, sprintf('%s.fig', ANALYSIS));
% saveas(gcf, sprintf('%s.png', ANALYSIS));
% grid on

progLen = 12;
memAccessIdx = [3 6 9];
currentM = [4 9 10 12];

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

memidxBase = constrUB - constrLB + 1;
memidxRange = prod(memidxBase);

X = [];

variant = zeros(numAccesses, 1);
for i = 1:memidxRange
    eidx = i - 1;
    j = 1;
    while eidx > 0 && j <= numAccesses
        offset= mod(eidx, memidxBase(j));
        variant(j) = constrLB(j) + offset;
        eidx = floor(eidx / memidxBase(j));
        j = j + 1;
    end
    pfx = A * variant;
    if all(pfx >= constrDelta)
        X = [X; variant'];
    end
end

% plot3(X( : , 1), X( : , 2), X( : , 3), '-o');
% title('Feasibility region for valid program');
% xlabel('M1');
% ylabel('M2');
% zlabel('M3');
% grid on

current = zeros(1, NUM_STAGES);
current(currentM) = 1;

X_0 = [];
X_1 = [];
X_2 = [];
X_3 = [];
Y = zeros(length(X), 1);
for i = 1:size(X, 1)
    mapped = zeros(1, NUM_STAGES);
    mapped(X(i, : )) = 1;
    overlaps = dot(mapped, current);
    Y(i) = overlaps;
    if overlaps == 0
        X_0 = [X_0; X(i, : )];
    elseif overlaps == 1
        X_1 = [X_1; X(i, : )];
    elseif overlaps == 2
        X_2 = [X_2; X(i, : )];
    elseif overlaps == 3
        X_3 = [X_3; X(i, : )];
    else
        disp('Error: Cannot have more than 3 overaps!');
    end
end

D = zeros(length(X), 1);
for i = 1:length(X)
    x = X(i, : );
    D(i) = x(1)^2 + x(2)^2 + x(3)^2;
end

figure
yyaxis left
plot(1:length(X), D);
ylabel('Distance from (0,0,0)');
yyaxis right
plot(1:length(X), Y, '-o');
title('Enumeration sequence vs overlaps');
xlabel('Sequence #');
ylabel('Overlaps');
set(gca, 'FontSize', 16);
grid on

% % figure
% plot3(X( : , 1), X( : , 2), X( : , 3), '-o');
% hold on
% plot3(X_0( : , 1), X_0( : , 2), X_0( : , 3), '-x');
% hold on
% plot3(X_1( : , 1), X_1( : , 2), X_1( : , 3), '-x');
% hold on
% plot3(X_2( : , 1), X_2( : , 2), X_2( : , 3), '-x');
% hold on
% plot3(X_3( : , 1), X_3( : , 2), X_3( : , 3), '-x');
% legend('overall', '0-overlap', '1-overlap', '2-overlap', '3-overlap');
% title('Feasibility region (allocations)');
% xlabel('M1');
% ylabel('M2');
% zlabel('M3');
% set(gca, 'FontSize', 16);
% grid on

% figure
% 
% subplot(2,2,1);
% plot3(X_0( : , 1), X_0( : , 2), X_0( : , 3), '-x');
% title('Feasibility region (0 overlap)');
% xlabel('M1');
% ylabel('M2');
% zlabel('M3');
% grid on
% 
% subplot(2,2,2);
% plot3(X_1( : , 1), X_1( : , 2), X_1( : , 3), '-x');
% title('Feasibility region (1 overlap)');
% xlabel('M1');
% ylabel('M2');
% zlabel('M3');
% grid on
% 
% subplot(2,2,3);
% plot3(X_2( : , 1), X_2( : , 2), X_2( : , 3), '-x');
% title('Feasibility region (2 overlap)');
% xlabel('M1');
% ylabel('M2');
% zlabel('M3');
% grid on
% 
% subplot(2,2,4);
% plot3(X_3( : , 1), X_3( : , 2), X_3( : , 3), '-x');
% title('Feasibility region (3 overlap)');
% xlabel('M1');
% ylabel('M2');
% zlabel('M3');
% grid on