clear;
clc

N = 20;
M = 5;
ALLOCSIZE = N * M;

A = zeros(ALLOCSIZE, ALLOCSIZE);
for i = 1:ALLOCSIZE
    if mod(i, N) == 1
        A(i, i) = 1;
    else
        A(i, i - 1) = -1;
        A(i, i) = 1;
    end
end
B = zeros(ALLOCSIZE, 1);
for i = 1:ALLOCSIZE
    if mod(i, N) == 1
        B(i) = 3;
        B(i + 1) = 4;
    end
end

UL = zeros(ALLOCSIZE, 1);
for i = 1:ALLOCSIZE
    if mod(i, N) == 1
        UL(i) = 7;
        UL(i + 1) = 19;
    end
end

LL = zeros(ALLOCSIZE, 1);
x0 = zeros(ALLOCSIZE, 1);
for i = 1:ALLOCSIZE
    if mod(i, N) == 1
        x0(i) = 3;
        x0(i + 1) = 7;
        LL(i) = 1;
        LL(i + 1) = 1;
    end
end

f = @(x) sum(x' ~= x0);
nlcon = @(x) deal(numel(find(x)) - numel(unique(x(x>0))), []);

options = optimoptions('ga', 'ConstraintTolerance', 1e-6, 'PlotFcn', @gaplotbestf);

[x, fval, exitflag, output] = ga(f, ALLOCSIZE, A, B, [], [], LL, UL, nlcon, 1:ALLOCSIZE, options);

% nlcon = @(x) deal([], numel(unique(x(x>0))) - numel(find(x)));
% opts = optimoptions(@fmincon, 'Algorithm', 'interior-point');
% prob = createOptimProblem('fmincon', ...
%     'options', opts, ...
%     'x0', x0, ...
%     'objective', f, ...
%     'lb', LL, ...
%     'ub', UL, ...
%     'nonlcon', nlcon, ...
%     'Aineq', A, 'bineq', B ...
% );
% allocation = run(GlobalSearch, prob);