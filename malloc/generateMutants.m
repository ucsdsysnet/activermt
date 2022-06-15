function [mutants] = generateMutants(plen, midx, constr_max_stage)
%{
assume: memory ops are non-commutative.
assume: most compact midx is provided as input.
constr: specify min instructions separating two mem accesses (B).
constr: specify max index for memory op (L).
%}
    midx_sparse = find(midx);
    num_memaccess = length(midx_sparse);
    A = zeros(num_memaccess);
    A(1,1) = 1;
    for r = 2:num_memaccess
        for c = 1:num_memaccess
            if r - 1 == c
                A(r, c) = -1;
            elseif r == c
                A(r, c) = 1;
            end
        end
    end
    B = A * midx_sparse';
    L = constr_max_stage(find(constr_max_stage));
    base = zeros(num_memaccess, 1);
    idxlim = 20 - plen + midx_sparse(end);
    max_mutants = 1;
    for i = num_memaccess:-1:1
        base(i) = idxlim;
        max_mutants = max_mutants * idxlim;
        idxlim = idxlim - 1;
    end
    mutants = [];
    for i = 1:max_mutants
        eidx = i - 1;
        j = 1;
        mutant = zeros(num_memaccess, 1);
        while eidx > 0 && j <= num_memaccess
            mutant(j) = mod(eidx, base(j));
            eidx = floor(eidx / base(j));
            j = j + 1;
        end
        mutant = mutant + 1;
        pfx = A * mutant;
        if all(mutant <= L') && all(pfx >= B)
            m = zeros(length(midx), 1);
            m(mutant) = 1;
            mutants = [mutants m];
        end
    end
%     num_stages = length(midx);
%     num_constr = size(constr_max_stage, 1);
%     i = 1; 
%     j = plen;
%     midx_compact = midx(1:plen);
%     while j <= num_stages && all((midx * i) <= constr_max_stage)
%         mutant = zeros(num_stages, 1);
%         mutant(i:j) = midx_compact;
%         mutants = [mutants, mutant];
%         i = i + 1;
%         j = j + 1;
%     end
end

