function [mo,ord] = arrminf(mi0,maxpass,fignum,ord0,cax)
% ARRMINF Reorders a pairwise mutual information matrix for an n-dimensional signal.
%   [mo,ord] = arrminf(mi0, maxpass, fignum, ord0, cax) reorders the pairwise mutual
%   information matrix mi0 for an n-dimensional signal. The function returns the
%   reordered matrix mo and the corresponding order of rows/columns in ord. The
%   optional inputs are:
%       - maxpass: Maximum number of passes to perform. Default is 3.
%       - fignum: Figure number to display the reordered matrix. Default is a new figure.
%       - ord0: Initial order of rows/columns. Default is the natural order.
%       - cax: Color axis limits for the figure.
%
% 
% (c) Seyed Yahya Shirazi, 07/2023 UCSD, INC, SCCN

mi = mi0;
[m,n] = size(mi);
% Check if initial order is provided, otherwise use the natural order
if nargin < 4 || ord0 == -1
    ord = 1:n;
else
    ord = ord0;
end
still_changing = 1;
pass = 0;
% Check if maxpass is provided, otherwise use default value 3
if nargin < 2
    maxpass = 3;
end
% Check if maxpass is provided, otherwise use default value 3
if nargin < 3
    f = figure;
else
    f = fignum;
end
% Display the initial matrix
figure(f), imagesc(mi);
drawnow

% Initialization based on column sums
if nargin < 4 || ord0 == -1
    [~,ord] = sort(sum(mi,1),'descend');
    mi = mi(ord,ord);
end

while still_changing && pass < maxpass
    pass = pass+1;
    still_changing = 0;
    odg = zeros(n);
     % Loop over each element to compute the off-diagonal costs
    for k = 1:n
        ok = offdiag(mi(k,:), n, k);
%         odg(k,k) = 0;
        disp("1\n")
        parfor t = 1:n
            ot = offdiag(mi(t,:), n, t);
            tmp = zeros(1,n);
%             disp("2\n")
             % Loop over each possible swap s
            for s = 1:n
                if ~(s == k && t == k)
                    oks = offdiag(mi(k,:), s, n);
                    otk = offdiag(mi(t,:), k, n);
                    ost = offdiag(mi(s,:), t, n);
                    os = offdiag(mi(s,:), s, n);
                    tmp(s) = oks + otk + ost - ok - ot - os;
%                     disp("3")
                end
            end
             % Store the computed off-diagonal costs for swap (k,t)
            odg(t, :) = tmp;
        end
        % Find the indices of the minimum off-diagonal cost
        [mn,indi] = min(odg);
        [mn2,indj] = min(mn);

         % Perform the swaps based on the minimum off-diagonal cost
        if ~(indi(indj) == k && indj == k)
            [mi, ord] = doswap(mi, ord, k, indi(indj));
            [mi, ord] = doswap(mi, ord, indi(indj), indj);
            still_changing = 1;
        end
        if mod(k,10)==0
            figure(f), imagesc(mi), colorbar
            if nargin > 4
                caxis(cax);
            end
            drawnow;
        end
    end
end

mo = mi;
end


function [mi, ord] = doswap(mi, ord, i, j)
% DOSWAP Swaps rows and columns in the mutual information matrix and updates the order
%   [mi, ord] = doswap(mi, ord, i, j) swaps rows and columns i and j in the mutual
%   information matrix mi, and updates the order of rows/columns in ord.

mi = swaprow(mi, i, j);
mi = swapcol(mi, i, j);
tmp = ord(i);
ord(i) = ord(j);
ord(j) = tmp;
end

function mi = swaprow(mi, i, j)
    tmp = mi(i,:);
    mi(i,:) = mi(j,:);
    mi(j,:) = tmp;
end

function mi = swapcol(mi, i, j)
    tmp = mi(:,i);
    mi(:,i) = mi(:,j);
    mi(:,j) = tmp;
end
