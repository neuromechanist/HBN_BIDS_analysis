function pvals = mcorrect(pvals, method)

switch method
    case {'no' 'none'}, return;
    case 'bonferoni', pvals = pvals*prod(size(pvals));
    case 'holms',     [tmp ind] = sort(pvals(:)); [tmp ind2] = sort(ind); pvals(:) = pvals(:).*(prod(size(pvals))-ind2+1);
    case 'fdr',       pvals = fdr(pvals);
    otherwise error(['Unknown method ''' method ''' for correction for multiple comparisons' ]);
end  