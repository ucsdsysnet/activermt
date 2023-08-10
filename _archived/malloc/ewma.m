function [result] = ewma(x, alpha)
    assert(isvector(x));
    n = length(x);
    result = zeros(1, n);
    result(1) = x(1);
    for i = 2:n
        result(i) = alpha * x(i) + (1- alpha) * result(i - 1);
    end
end