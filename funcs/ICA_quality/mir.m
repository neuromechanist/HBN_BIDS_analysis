function [mutual_info,mutual_info_var, detailed_mir] = mir(data,linT)
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
% (c) Seyed Yahya Shirazi, 06/2023 UCSD, INC, SCCN, from github.com/bigdelys/pre_ICA_Cleaing/getMIR.m

[hx,vx] = getent4(robust_sphering_matrix(data) * data); % sphereing is needed to make sure that the MIR is only related to ICA

y = linT*data;

[hy,vy] = getent4(y);

mutual_info = sum(log(abs(eig(W)))) + sum(hx) - sum(hy);

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
