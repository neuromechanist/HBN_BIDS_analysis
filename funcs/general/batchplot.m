function [bnum bval] = batchplot(data, batchsize, calctype, errorbandtype, color2use, dim)

% BATCHPLOT, calculates mean, min, max, median, or rms (root mean square)
%   of batches of points. A batch is a group of points of BATCHSIZE. 
%   So, if BATCHSIZE = 5, then each batch is every group of 5 points.
%   If BATCHSIZE = 1, then BVAL = DATA. If BATCHSIZE = length(DATA), then
%   BVAL give metric for the whole column.
%
%   [BNUM BVAL] = BATCHPLOT(DATA, BATCHSIZE) calculates the mean of each 
%   BATCHSIZE of points in a vector or 2D matrix DATA. If 2D, BATCHPLOT
%   computes batches along each column. BNUM is a vector of batch numbers. 
%   BVAL returns mean for each batch in each col.
%
%   Ex. if DATA is 900 x 2 and BATCHSIZE equals 5, then there are 
%   900/5 = 180 batches. BNUM = 1:1:180. Size(BVAL) = [180, 2]; 
%   BVAL(1,1) = nanmean(DATA(1:5,1)); BVAL(1,2) = nanmean(DATA(1:5,2));
%   BVAL(2,1) = nanmean(DATA(6:10,1)); BVAL(2,2) = nanmean(DATA(6:10,2));
%   ...etc.
%
%   [BNUM BVAL] = BATCHPLOT(DATA, BATCHSIZE, CALCTYPE) specifies metric to
%   be calculated in each batch. Options are 'mean', 'med', 'max', 'min',
%   and 'rms'. Actually calls nan related functions, in case there are nans
%   in DATA. i.e. uses nanmean instead of mean. Ex. to calculate max in
%   each batch, [BNUM BVAL] = BATCHPLOT(DATA, BATCHSIZE, 'max').
%
%   [BNUM BVAL] = BATCHPLOT(DATA, BATCHSIZE, CALCTYPE, DIM) can be used to
%   calculate batches along each row, versus each column, by setting  
%   DIM = 2. Ex. if size(DATA) = [2 900], setting DIM = 2, yields BNUM =
%   1:1:180.
%
%   BATCHPLOT(DATA, BATCHSIZE, ...) plots BNUM on the x-axis and BVAL on
%   the y-axis. If BVAL has multiple columns, then nanmean(BVAL) +/- 
%   nanstd(BVAL)/sqrt(bnum) is plotted. Ex. DATA is movement error where the rows are
%   trials and each column is an individual subject. The resulting plot
%   will be the group average +/- sem. movement error by batch.
%
%   Written by Helen J. Huang, 23 Mar 2011

error(nargchk(2, 6, nargin));

if nargin == 2
    % default to 'mean', if calctype is not specified
    calctype = 'mean';
elseif nargin >= 3 && ~ismember(calctype,{'mean' 'med' 'max' 'min' 'rms' 'sum'})
    error('Invalid calculation type. Must be mean, med, max, min, rms or sum');
elseif nargin < 4
    % default to 'mean', if calctype is not specified
    errorbandtype = 'sem';
elseif nargin >= 4 && ~ismember(errorbandtype,{'sem' 'sd'})
    error('Invalid calculation errorband type. Must be sem or sd. Default sem');
elseif nargin < 5    
    color2use = [0 0 1]; % = blue in [R G B]
    dim = 1;
elseif nargin < 6
    dim = 1;
end

if length(size(data)) ~= 2
    error('Data must be 1D or 2D');
end

% Data in rows, transpose to put data into cols
% rows = time and eventually batches
% columns are data points to average
% if dim == 2 || size(data,1) < size(data,2)
%     data = data';
% end

dims = size(data);

numbatches = floor(dims(1)/batchsize);
if numbatches == 0
    error('No batches computed. Check dimensions, i.e. batchsize > dimension that the batches are to be calculated along');
elseif mod(dims(1),batchsize) ~= 0
    disp('Note: Data is not a multiple of batchsize. i.e. partial batch');
end

switch calctype
    case 'mean'
        batchcmd = 'bval(b,:) = nanmean(datasubset,1);';
    case 'med'
        batchcmd = 'bval(b,:) = nanmedian(datasubset,1);';
    case 'max'
        batchcmd = 'bval(b,:) = nanmax(datasubset,[],1);';
    case 'min'
        batchcmd = 'bval(b,:) = nanmin(datasubset,[],1);';
    case 'rms'
        batchcmd = 'bval(b,:) = rms(datasubset,1);';
    case 'sum'
        batchcmd = 'bval(b,:) = nansum(datasubset,1);';
end

switch errorbandtype
    case 'sem'
        errorcmd = 'bvalerror = nanstd(bval, 0, 2)/sqrt(size(data,2));';
    case 'sd'
        errorcmd = 'bvalerror = nanstd(bval, 0, 2);';
end
bnum = nan(numbatches,1);
for b = 1:numbatches
    idx1 = (((b-1)*batchsize)+1);
    idx2 = b*batchsize;
    datasubset = data(idx1:idx2,:);
    eval(batchcmd);
    bnum(b) = b;
end

if nargout == 0
    bvalmean = nanmean(bval, 2);
    eval(errorcmd);
    if size(bval,2) > 1
        hold on;
        patch([bnum; flipud(bnum)], [bvalmean+bvalerror; flipud(bvalmean-bvalerror)], color2use, 'EdgeColor', color2use, 'facealpha', 0.5, 'edgealpha', 0.5);
    end
    plot(bnum, bvalmean, 'color', color2use)
end