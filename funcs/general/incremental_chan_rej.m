function [ICA_STRUCT, chan_rej_log] = incremental_chan_rej(EEG, tcr_chans, ret_tcr_chan, incr, good_chans,path,saveF)
% This function rejects channles in increments and saves the results in the
% output arrays.
%
% INPUTS:
%       EEG: EEGLAB's EEG structure containing all data for a subject and
%            prefrerrabley without prior channel rejectoin
%       TCR_CHANS: channels that should be rejected based on TCR.
%       INCR: number of increments for channle rejection. Default = 8.
%       GOOD_CHANS: optional input, index of channels that will not be
%                   rejected these channels will be removed from the input
%                   EEG structure before performing channel rejection and
%                   will automatically be added to ICA_STRUCT.good_chans.
%                   Default = [];
%       PATH: the path to save figure files.
%
%
% REV:
%       v0 @ 5/10/2019 adapted from chan_rej_hjh_tcr
%
%
% Created by: Seyed Yahya Shirazi, BRaIN Lab, UCF
% email: shirazi@ieee.org
%
% Copyright 2019 Seyed Yahya Shirazi, UCF, Orlando, FL 32826

%% initialize

if ~exist('EEG','var'), error("No EEG structure is defined, chan_reject terminated."); end
if ~exist('tcr_chans','var'), tcr_chans = []; end
% retun the TCR rejected channel to the group in the final step. This is
% useful for the reutrned of the refrecne channel (eg Cz for EGI).
if ~exist('ret_tcr_chan','var'), ret_tcr_chan = 0; end 
if ~exist('incr','var') || isempty(incr), incr = [5 4 3.5 3 2.75 2.5 2.25 2]; end
if ~exist('good_chans','var'), good_chans = []; end
if ~exist('path','var'), path = []; else, path = string(path); end
if ~exist('saveF','var'), saveF = 0; end

rej_methods = ["range", "std", "kurt", "corr"];
corr_ther = [.05 .04 .03 .02 .015 .01 .005 .001];
kurt_ther = [10 8 6 5 4.5 4 3.5 3];
max_chan_to_remove = 50;
% removing the good channles from the rejection pool. They will be added
% to ICA_STRUCT later.
EEG = pop_select(EEG,'nochannel',good_chans);

%% remove TCR channles
EEG_OG = EEG; % making sure that there is a copy of the OG data.
if ~isempty(tcr_chans)
    disp("TCR: removing bad channels");
    chan_names = {EEG.chanlocs.labels};
    rej_chan_idx = tcr_chans;
    disp(chan_names(rej_chan_idx));
    EEG = pop_select(EEG,'nochannel',chan_names(rej_chan_idx));
end

%% range criterion
% Default criterion for rejection was [30 10000]
chan.range.raw = transpose(range(EEG.data,2));
[chan.range.sorted, chan.range.index] = sort(chan.range.raw,"descend");

%% standard deviation criterion
% Default criterion for rejection was std(std(chans)) > 2 
chan.std.raw = transpose(std(EEG.data,0,2));
[chan.std.sorted, chan.std.index] = sort(chan.std.raw,"descend");
chan.std.median = median(chan.std.sorted);
chan.std.std = std(chan.std.sorted);

%% kurtosis
% Default criterion for kurtosis rejection was 5
[~, ~, chan.kurt.raw] = pop_rejchan(EEG,'elec',1:EEG.nbchan,'threshold',5,...
    'norm','on','measure','kurt');
chan.kurt.raw = chan.kurt.raw';

%% correlation
% Dafault criterion for correltation was if any channel is correlation
% lower than 0.4 for x = 0.0001 of the time. x can be configured. Instead I
% have to have the correlation values for each channel and perform outlier
% analysis. A drawback of this method is that I will lose the iterative
% nature of updating correlation of chanlles once bad channles are removed.
[~, chan.corr.raw] = eeg_badChannelsByCorr(EEG);

%% creating incremental outlier

for i = incr
    outlier{i==incr} = [];
    for j = rej_methods
        if j == "range" || j == "std"
            chan.(j).outlier{i==incr} = find(isoutlier(chan.(j).raw,"median","ThresholdFactor",i));
        elseif j == "kurt"
            chan.(j).outlier{i==incr} = find(chan.(j).raw > kurt_ther(i==incr));
        else
            chan.(j).outlier{i==incr} = find(chan.(j).raw > corr_ther(i==incr));
        end
        outlier{i==incr} = [outlier{i==incr} chan.(j).outlier{i==incr}];
        outlier{i==incr} = unique(outlier{i==incr});
    end
end

% We should make cap of 50 (arbitrary) number of electrodes to be removed,
% otherwise, this method can potantially remove the majority of the
% channels.

for i = 1:length(outlier)
    if length(outlier{i}) + length(tcr_chans) > max_chan_to_remove
        disp("there are more than " + string(max_chan_to_remove) + ...
            ". Capping the rejecttion to the maximum")
        if i > 1
            t_outlier = outlier{i-1};
            rem_out_chans = setdiff(outlier{i},t_outlier);
            rem_length = max_chan_to_remove - (length(t_outlier)+ length(tcr_chans));
            rem_out_chans = rem_out_chans(randperm(numel(rem_out_chans),rem_length));
            outlier{i} = [t_outlier rem_out_chans];
        else
            error("Most lenient chan rejaction passed maximum rejection threshold")
        end
    end
end

%% make some plots
for i = 1:length(incr)
   figure("Name","rejected channels for increment No. " + string(i),"Units","normalized","OuterPosition",[.3 .3 .5 .7])
   for j = rej_methods
      subplot(2,2,find(j==rej_methods))
      plot(chan.(j).raw,'o')
      hold on
      plot(chan.(j).outlier{i},chan.(j).raw(chan.(j).outlier{i}),'ro');
      title(j)
      sgtitle("rejected chans in incr. " + string(i))
   end
   drawnow;
   if saveF
   saveas(gcf,path + "rej_metrics_incr_" + string(i),"png");
   saveas(gcf,path + "rej_metrics_incr_" + string(i),"fig");
   end
end
   
figure("Name","rejected channles on topoplot","Units","normalized","OuterPosition",[.1 .1 .8 .8])
for i = 1:length(incr)
    subplot(2,ceil(length(incr)/2),i)
    mod_topoplot([],EEG.chanlocs,'electrodes','on','emarker',{1:EEG.nbchan,'.','k',10,1},...
        'emarker2',{outlier{i},'.','r',20,1});
    
    drawnow;
    title("incr. No" + string(i));
    sgtitle("rejected channels using incremental rejection")
end
if saveF
saveas(gcf,path + "incremental_chan_rej_topo","png");
saveas(gcf,path + "incremental_chan_rej_topo","fig");
end

%% create output
% original_chan_list = 1:EEG.nbchan; % after remvoing good_chans and tcr_chans
frames = 1:EEG.pnts; %to start with use all frames

for i = 1:length(incr)
   chan_names = {EEG.chanlocs.labels};
   EEG_temp(i) = pop_select(EEG,'nochannel', chan_names(outlier{i}));
   for n = 1:EEG_temp(i).nbchan
    ICA_STRUCT(i).good_chans(n) = EEG_temp(i).chanlocs(n).urchan;
   end
   if ret_tcr_chan, ICA_STRUCT(i).good_chans(end+1) = EEG_OG.chanlocs(end).urchan; end
   ICA_STRUCT(i).associated_set = [EEG_temp(i).setname '_incr_' num2str(i)];
   ICA_STRUCT(i).chan_rej_frames_used = frames;
   ICA_STRUCT(i).ref = 'averef';
end


% for i = 1:length(incr)
%     passed_chans = original_chan_list;
%     passed_chans(outlier{i}) = [];
%     ICA_STRUCT(i).good_chans = sort([passed_chans good_chans]);
%     ICA_STRUCT(i).associated_set = EEG.setname;
%     ICA_STRUCT(i).chan_rej_frames_used = frames;
%     ICA_STRUCT(i).ref = 'averef';
% end

chan_rej_log = "Incremental channel rejection";