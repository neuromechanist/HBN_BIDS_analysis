function [mo,ord] = arrminf(mi,varargin)
% ARRMINF Reorders a pairwise mutual information matrix for an n-dimensional signal.
%   [mo,ord] = arrminf(mi0, maxpass, fignum, ord0, cax) reorders the pairwise mutual
%   information matrix mi0 for an n-dimensional signal. The function returns the
%   reordered matrix mo and the corresponding order of rows/columns in ord. The
%   optional inputs are:
%       - maxPass: Maximum number of passes to perform. Default is 3.
%       - figHandle: Figure number to display the reordered matrix. Default is a new figure.
%       - sortOrder: Initial order of rows/columns. Default is the natural order.
%       - cax: Color axis limits for the figure.
%
% 
% (c) Seyed Yahya Shirazi, 07/2023 UCSD, INC, SCCN, from sccn/postAmicaUtility/arrminf2.m

%% parse the inputs
opts = arg_define(varargin, ...
    arg({'maxPass','maxpass','max_pass'}, 3,[],'maximum number of passes to perform.'), ...
    arg({'sortOrder','sortorder', 'sort_order', 'ord0'}, -1,[],'Initial order of rows/columns. Default is the natural order.'), ...
    arg({'colorLim','colorlim', 'color_lim'}, [],[],'The range for the color limit. Default is empty'), ...
    arg({'figHandle','fighandle','fig_handle'}, [],[],'Figure handle to display the reordered matrix. Default (empty) is a new figure.'), ...
    arg({'showFig','showfig','show_fig'}, 1,[0 1],'Whether to plot the figures. Default is true.'),...
    arg({'saveFig','savefig','save_fig'}, 0,[0 1],'Whether to save the figures. Default is false.'),...
    arg({'saveTemp','savetemp','save_temp'}, 1,[0 1],'Whether to write the intermediate steps into a file temporary files. Default is false.'),...
    arg({'writeStep','writestep','write_step'}, 20,[],'When to write the step files or update the plot. Default is 20'),...
    arg({'keepOneStep','keep_one_step'}, 1,[0 1],'Whether to keep the last temp file or keep all. Default is 1 to only keep the keep last.'),...
    arg({'figPath','figpath','fig_path'}, './',[],'The path for saving the figures, default is the current directory.'),...
    arg({'filePath','filepath','file_path'}, './tmpresults/',[],'The path for saving the intermediate files, default is the current directory under tmpresults subdirectory.'),...
    arg({'deleteTempFiles'}, 0,[0 1],'Whether to delete the temporary files if the function is sucessfully finishes. Default is false.'),...
    arg({'useParallel', 'useparallel', 'use_parallel'}, 1,[0 1],'Whether to use Matlab Parallel Computing Toolbox. Default is true.'));

%% intialize variables
[~,n] = size(mi);

% Check if maxpass is provided, otherwise use default value 3
if isempty(opts.figPath), f = figure(); else, f = opts.figHandle; end
if opts.showFig, if isempty(opts.figHandle), f = figure; end, figure(f), imagesc(mi); drawnow; end
% Check if initial order is provided, otherwise use the descending column order
if opts.sortOrder == -1, [~,ord] = sort(sum(mi,1),'descend'); else, ord = opts.sortOrder; end
% Initialization based on column sums
mi = mi(ord,ord);

% Display the initial matrix
if ~opts.showFig, opts.saveFig = 0; end


if exist(opts.filePath,"dir") && opts.saveTemp, warning('temp folder exist, contents will be deleted'); end
if ~exist(opts.filePath,"dir") && opts.saveTemp, mkdir(opts.filePath); end

if ~exist(opts.figPath,"dir") && opts.saveFig, warning('figure folder exist, contents may be overwritten'); end
if ~exist(opts.figPath,"dir") && opts.saveFig, mkdir(opts.figPath); end

if opts.useParallel
    instToolboxes = ver; % the list of installed toolboxes
    if ~license('test','Distrib_Computing_Toolbox') || ~contains([instToolboxes(:).Name],{'Parallel Computing Toolbox', 'Parallel Computing Toolbox'})
        warning('Parallel computing is selected but it is not available or licensed. Spectopo will fall back to non-parallel processing')
        opts.useParallel = 0;
        numWorkers = 1;
    else
        poolobj = gcp('nocreate'); % This only uses parallel pool if one is already available
        if isempty(poolobj); poolobj = parpool; end
        numWorkers = poolobj.NumWorkers;
        disp('Reordering MI using parpool')
    end
else, numWorkers = 1; % to maintain consistency and run wihtouh parallel toolbox.
end

%% main loop
still_changing = 1;
pass = 0;
while still_changing && pass < opts.maxPass
    pass = pass+1;
    still_changing = 0;
    odg = zeros(n);
     % Loop over each element to compute the off-diagonal costs
    for k = 1:n
        ok = offdiag(mi(k,:), n, k);
        fprintf(".")
        parfor(t = 1:n, numWorkers)
            ot = offdiag(mi(t,:), n, t);
            tmp = zeros(1,n);
             % Loop over each possible swap s
            for s = 1:n
                if ~(s == k && t == k)
                    oks = offdiag(mi(k,:), s, n); %#ok<PFBNS> 
                    otk = offdiag(mi(t,:), k, n);
                    ost = offdiag(mi(s,:), t, n);
                    os = offdiag(mi(s,:), s, n);
                    tmp(s) = oks + otk + ost - ok - ot - os;
                end
            end
             % Store the computed off-diagonal costs for swap (k,t)
            odg(t, :) = tmp;
        end
        % Find the indices of the minimum off-diagonal cost
        [mn,indi] = min(odg);
        [~,indj] = min(mn);

         % Perform the swaps based on the minimum off-diagonal cost
        if ~(indi(indj) == k && indj == k)
            [mi, ord] = doswap(mi, ord, k, indi(indj));
            [mi, ord] = doswap(mi, ord, indi(indj), indj);
            still_changing = 1;
        end
        if mod(k,opts.writeStep)==0
            fprintf("\n")
            if opts.showFig
                figure(f), imagesc(mi), colorbar; if ~isempty(opts.colorLim), clim(opts.colorLim); end, drawnow;
            end
            if opts.saveTemp && opts.keepOneStep, delete([opts.filePath '*.mat']); end
            if opts.saveTemp, save([opts.filePath '/temp_mi_pass-' num2str(pass) '_step-' num2str(k) '.mat'],'mi','ord'); end
            if opts.saveFig, print(f, [opts.figPath '/ordered_mi_pass-' num2str(pass) '_step-' num2str(k) '.pdf'],'-dpdf','-vector'); end
        end
    end
end

mo = mi;
if opts.deleteTempFiles, rmdir(opts.filePath,'s'); end
end

%% helper functions
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
