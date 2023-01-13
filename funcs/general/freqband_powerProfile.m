function powerProfile = freqband_powerProfile(masked_ersp,allfreqs,alltimes,freqband) %#ok<INUSL>
% Sometiems, there is the need to look for activities ina certain frequncy
% band across time, for example to see when is the majority of the
% activitiy starts or if activitites in certain connditions are stronger.
% inputs:
%       erspdata: a cell array containing the ersp data from "readersp.m"
%       allfreqs: a 1 x n vector containing the freqency values for ersp.
%       alltimes: a 1 x n vector containing the time values for ersp.
%       freqband: the freqband you wish to do the integration on.
%
% Created by: Seyed Yahya Shirazi, 12/3/19 UCF
%% find the indices on the freqband
if ~exist("freqband","var") || isempty(freqband)
    error("A freqband (1 x 2 verctor) is needed to calcucate powerProfile")
else
    freqband = sort(freqband);
end
freq_idx = find(allfreqs > freqband(1) & allfreqs < freqband(2));

%% main loop
conds = string(transpose(fieldnames(masked_ersp)));
for c = conds
    powerProfile(c==conds).individual_sum = transpose(squeeze(mean(masked_ersp.(c)(freq_idx,:,:),1))); %#ok<FNDSB>
%     powerProfile(c==conds).individual_outlier = isoutlier(powerProfile(c==conds).individual_sum,'gesd','MaxNumOutliers',2);
%     powerProfile(c==conds).individual_outlierSum = sum(powerProfile(c==conds).individual_outlier,1);
%     powerProfile(c==conds).individual_sum(powerProfile(c==conds).individual_outlier) = nan;
    powerProfile(c==conds).ensemble_mean = nanmean(powerProfile(c==conds).individual_sum,1);
    powerProfile(c==conds).ensemble_std = nanstd(powerProfile(c==conds).individual_sum,0,1);
    powerProfile(c==conds).ensemble_ste = powerProfile(c==conds).ensemble_std/sqrt(size(powerProfile(c==conds).individual_sum,1));
    confInt = tinv([0.025 0.975], size(powerProfile(c==conds).individual_sum,1)-1);
    powerProfile(c==conds).ensemble_unsignedConfInt = powerProfile(c==conds).ensemble_ste * confInt(2); % the second element is the positive confInt. confInt is symmetric.
    powerProfile(c==conds).ensemble_median = median(powerProfile(c==conds).individual_sum,1);
    powerProfile(c==conds).ensemble_iqr = iqr(powerProfile(c==conds).individual_sum,1);    
end
