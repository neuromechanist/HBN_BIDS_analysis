function [mutual_info,mutual_info_var, detailed_mir] = mir(data, icaweights, icasphere, beyond_pca)
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

% Reducae data rank using pca, if LinT and data have different channel count.

if ~exist("icasphere","var") || isempty(icasphere)
    has_sphere = 0;
    linT = icaweights;
else
    has_shpere = 1;
    linT = icaweights * icasphere;
end

if ~exist("method","var") || isempty(beyond_pca),  beyond_pca = "off"; end


if size(linT,1) == size(linT,2)
    sq_linT = 1; % square linear transformation matrix 
else
    sq_linT = 0;
    % check if the data is compatible with linT. This happens if LinT can't be left multiplied to data
    if size(linT, 2) ~= size(data,1), error("data does not mathc the linear Tranformation, exiting"); end
    warning("data and IC ranks are not the same, will reduce data rank using icaspehre (if present) or PCA")
end

if sq_linT == 0
    % if has_shpere
    %     pc_sphered_data = icasphere * data;
    % else
        num_pcs_to_keep = size(icaweights,1);
        pcs = transpose(pca(data')); % note the transpose 
        pc_data = pcs(1:num_pcs_to_keep,:) * data; % pc_act = pcs * data, pc_data = pinv(pcs)*pcs*data
        pc_sphered_data = robust_sphering_matrix(pc_data) * pc_data; % sphering is needed to ensure that MIR is related to ICA
    % end
else
    if has_sphere
        pc_sphered_data = icasphere * data;
    else
        warning("Sphere matrix is not present, the ICA results is not optimal, MIR is compared to the sphered data")
        pc_sphered_data = robust_sphering_matrix(data) * data;
    end
end

[hx,vx] = getent4(pc_sphered_data);
[hy,vy] = getent4(linT*data);

mutual_info = sum(log(abs(eig(icaweights)))) + sum(hx(~isinf(hx))) - sum(hy());


if nargout > 1
    mutual_info_var = (sum(vx)+sum(vy))/N;
elseif nargout > 2
    detailed_mir = []; % not yet implemented
end

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
