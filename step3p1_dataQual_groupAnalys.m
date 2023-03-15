function step3p1_dataQual_groupAnalys(participant_list, platform, machine, save_setfiles)
%STEP3P1_DATAQUAL_GROUPANALYS Summarizes results from step 3.
%   Following selecting the best increment for cleaning each dataset, we
%   need to run some group metrics to assess the cleaning and ICA
%   performance. The 
%
% (c) Seyed Yahya Shirazi, 03/2023 UCSD, INC, SCCN

%% initialize and adding paths
clearvars -except participant_list platform machine
close all; clc;
fs = string(filesep)+string(filesep);
mergedSetName = "everyEEG";

if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
p2l = init_paths(platform, machine, "HBN", 1, false);  % Initialize p2l and eeglab.
addpath(genpath(p2l.codebase))
if ~exist('participant_list', 'var') || isempty(participant_list)
    contents = dir(p2l.eegRepo);
    participant_list = string({contents.name});
    participant_list = participant_list(contains(participant_list,"NDAR"));
end
if ~exist('save_setfiles','var') || isempty(save_setfiles), save_setfiles = false; end
f2l.elocs = p2l.codebase + "funcs" + fs + "GSN_HydroCel_129_AdjustedLabels.sfp";

%% load ICA_structs
unavailable_participants = [];
for p = participant_list
    p2l.incr0 = p2l.eegRepo + p + fs + "ICA" + fs + "incr0" + fs;
    f2l.ICA_STRUCT.(p) = p2l.incr0 + p + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
    try
        temp_file = load(f2l.ICA_STRUCT.(p), "ICA_STRUCT");
        ICA_STRUCT.(p) = temp_file.ICA_STRUCT;
    catch
        unavailable_participants = [unavailable_participants p];
        participant_list(participant_list==p) = [];
    end
end

%% load EEG files as well
f = waitbar(0,'updating the set files with frame rejections','Name','please be patient');
for p = participant_list 
    p2l.EEGsets.(p) = p2l.eegRepo+ p + fs + "EEG_sets" + fs; % Where .set files are saved
    f2l.alltasks.(p) = p + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
    f2l.alltasks_cleaned.(p) = p + "_" + mergedSetName + "_stepwiseCleaned.set";
    if ~exist(p2l.EEGsets.(p) + f2l.alltasks_cleaned.(p), 'file')
        EEG = [];
        EEG = pop_loadset( 'filename', char(f2l.alltasks.(p)), 'filepath', char(p2l.EEGsets.(p)));
        EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});

        % update the set file with the frame rejection
        rejFrame = [];
        rejFrame.raw = ICA_STRUCT.(p).rej_frame_idx; % temporary rejected frames
        rejFrame.rowStart = [1 find(diff(rejFrame.raw) > 2)+1];
        for j = 1:length(rejFrame.rowStart)-1
            rejFrame.final(j,:) = [rejFrame.raw(rejFrame.rowStart(j)) rejFrame.raw(rejFrame.rowStart(j+1)-1)];
        end
        EEG = eeg_eegrej(EEG,rejFrame.final);

        if save_setfiles
            EEG.setname = char(f2l.alltasks_cleaned.(p));
            pop_saveset(EEG, 'filename', EEG.setname, 'filepath', char(p2l.EEGsets.(p)), 'savemode', 'twofiles');
        end
    end
    waitbar(find(participant_list==p)/length(participant_list),f)
end
