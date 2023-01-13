function powerProfile = freq_spectraProfile(masked_ersp)
% This function calcualates the average power spectra at each frequncy
% based on the ersp results, not doing another FFT. I think using the raw
% (not the de-baselined or masked) ERSP data is the only valid option to do
% the spectra using ERSP images.
%
% Created by: Seyed Yahya Shirazi, 12/4/19 UCF
%% main loop
conds = string(transpose(fieldnames(masked_ersp)));

for c = 1:length(conds)
    powerProfile(c).individual_sum = transpose(squeeze(mean(masked_ersp.(conds(c))(:,:,:),2)));
    powerProfile(c).ensemble_mean = mean(powerProfile(c).individual_sum,1);
    powerProfile(c).ensemble_std = std(powerProfile(c).individual_sum,0,1);
    powerProfile(c).ensemble_median = median(powerProfile(c).individual_sum,1);
    powerProfile(c).ensemble_iqr = iqr(powerProfile(c).individual_sum,1);    
end
