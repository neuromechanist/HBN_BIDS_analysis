% function compare_eeglab_versions
% this fucntion aims to compare the results of the ERSP analsyis from two
% different versions of EEGLAB to ensure consistency of the results across
% studies performed over the years.
% Current effort is to to compare ERSP results from EEGLAB 10.0.1.0 and
% EEGLAB 2019. A dataset from a subject was fed into std_precomp on both
% vreiosn and we need to compare the results.
%% initiallize
% root to load
r2l = "D:\academia\OneDrive - Knights - University of Central Florida\brain\eeg\PS\EEG\PS04\STUDY\incr0_amica\LEI";
E10 = load(r2l + "\PS04_LEI_base_epoch_UPL_tw_incr0_amica.icaersp","-mat");
E19 = load(r2l + "\PS04_LEI_new.icatimef","-mat");

%% 
% E10 is already and averaged ERSP results for the components, E19 contains
% individual ERSP data
ww = E19.comp14;
ww = ww .* conj(ww);
www = mean(ww,3);
