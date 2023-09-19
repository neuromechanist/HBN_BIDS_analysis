function [mutual_info,mutual_info_var, detailed_mir] = mir(data, icaweights, icasphere, sub_data, normalize, beyond_pca)
%MIR computes the mutual information reduction by a linear transformation
%   It so happends that simple codes are being used as event types in
%   EEG files. Such codes would be problamtic if proper descitiption is
%   not attached. A simple fix can be replacing the event codes with their
%   short descitpiotn using a lookup table.
%
%   INPUTS:
%       data
%           An [x t] array, usually EEG.data,  where the rows are the
%           channels and the columns are the time frames.
%       icaweights
%           The weight matrix for the ICA (or any other transforamtion).
%           While not required, it is usually a square matrix.
%       icasphere
%           The sphering/whitening matrix. Whitened data is known to
%           perfrom better in an ICA. This should be also a sqaure matrix,
%           unless the data rank is reduced.
%       sub_data
%           ratio or number of frames for subsampling the data. If the
%           number is less than one, only that ratio of the data is chosen
%           on random and used for MIR. If the number is an int and bigger
%           than one, only a subsample equal to that number will be used.
%       normalize
%           If true, a set of normlizing measures are applied in hopes to
%           make MIR a consistent metric for BSS quality.
%       boyond_pca
%           If true, the MIR would be quantified beyond the PCA
%           performance. The base data will go through PCA and whitening and
%           the MIR would be quantifed between this baseline the ICA
%           output.
%       linT
%           The linear transformation matrix, usually W * S, which should
%           is expected (but not necessarily) to be of size [x x].
%
%   OUTPUTS:
%       mir
%           The overal MIR across all channels
%       mir_var
%           The variance of the MIR across channels
%       detailed_mir
%           NOT_YET_IMPLEMENTED The vector containing the MIR per channel, i.e., how much
%           infomration of each channel is reduced.
%   
% (c) Seyed Yahya Shirazi, 06/2023 UCSD, INC, SCCN, from https://github.com/bigdelys/pre_ICA_cleaning/blob/master/getMIR.m

%% initialize
if ~exist("icasphere","var") || isempty(icasphere)
    has_sphere = 0;
    linT = icaweights; % The linear transformation matrix of ICA cobined with icasphere if present.
else
    has_sphere = 1;
    linT = icaweights * icasphere;
end

if ~exist("beyond_pca","var") || isempty(beyond_pca),  beyond_pca = false; end
if ~exist("sub_data","var") || isempty(sub_data),  sub_data = 0; end  % choose a subsample of the data

if sub_data == 0
    disp("using all data points for determine MIR")
elseif sub_data < 1
    disp("using "+string(sub_data)+" of the data to determine MIR")
elseif sub_data > 0 && sub_data < size(data,2)
    disp("using "+string(sub_data)+"data points to dtermine MIR")
else
    error("sub_data is used incorrectly.")
end
if ~exist("normalize","var") || isempty(normalize),  normalize = false; end
dev_by_suourceCount = false; % Normalize MIR by dividing it to the number of ICs. Requires addtional assumptions
if normalize == true % overwriting the options to make MIR a consistent metric
    beyond_pca = true;
    sub_data = 5e4;
    dev_by_suourceCount = true;
end

%% determine the baseline data, rank, etc.
if size(linT,1) == size(linT,2)
    sq_linT = 1; % square linear transformation matrix 
else
    sq_linT = 0;
    % check if the data is compatible with linT. This happens if LinT can't be left multiplied to data
    if size(linT, 2) ~= size(data,1), error("data does not mathc the linear Tranformation, exiting"); end
    warning("data and IC ranks are not the same, will reduce data rank using icaspehre (if present) or PCA")
end

if sq_linT == 0
    if has_shpere
        baseline_data = icasphere * data;
    else
        num_pcs_to_keep = size(icaweights,1);
        pcs = transpose(pca(data')); % note the transpose 
        pc_data = pcs(1:num_pcs_to_keep,:) * data; % pc_act = pcs * data, pc_data = pinv(pcs)*pcs*data
        baseline_data = robust_sphering_matrix(pc_data) * pc_data; % sphering is needed to ensure that MIR is related to ICA
    end
else
    if has_sphere
        baseline_data = icasphere * data;
    else
        warning("Sphere matrix is not present, ICA should not be optimal, MIR baseline is the RAW data")
        baseline_data = data;
    end
end

%% MIR
[hx,vx] = getent4(baseline_data);
[hy,vy] = getent4(linT*data);

mutual_info = sum(log(abs(eig(icaweights)))) + sum(hx(~isinf(hx))) - sum(hy());


if nargout > 1
    mutual_info_var = (sum(vx)+sum(vy))/N;
elseif nargout > 2
    detailed_mir = []; % not yet implemented
end

%% Auxiliary functions
function [Hu,v] = getent4(u,nbins)
% function [Hu,deltau] = getent2(u,nbins)
%
% Calculate nx1 marginal entropies of components of u.
%
% Inputs:
%           u       Matrix (n by N) of nu time series.
%           nbins   Number of bins to use in computing pdfs. Default is
%                   min(100,sqrt(N)).
%
% Outputs:
%           Hu      Vector n by 1 differential entropies of rows of u.
%           v       Variance of entropy estimates in Hu
%

[nu,Nu] = size(u);
if nargin < 2 || isempty(nbins)
    nbins = round(3*log2(1+Nu/10));
end

Hu = zeros(nu,1);
deltau = zeros(nu,1);
for i = 1:nu
    umax = max(u(i,:));
    umin = min(u(i,:));
    deltau(i) = (umax-umin)/nbins;
    u(i,:) = 1 + round((nbins - 1) * (u(i,:) - umin) / (umax - umin));

    pmfr = diff([0 find(diff(sort(u(i,:)))) Nu])/Nu;
    Hu(i) = -sum(pmfr.*log(pmfr));
    v(i) = sum(pmfr.*(log(pmfr).^2)) - Hu(i)^2;
    Hu(i) = Hu(i) + (nbins-1)/(2*Nu) + log(deltau(i));
end
