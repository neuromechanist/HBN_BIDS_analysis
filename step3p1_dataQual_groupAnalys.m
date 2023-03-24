function step3p1_dataQual_groupAnalys(participant_list, platform, machine, load_setfiles, save_setfiles)
%STEP3P1_DATAQUAL_GROUPANALYS Summarizes results from step 3.
%   Following selecting the best increment for cleaning each dataset, we
%   need to run some group metrics to assess the cleaning and ICA
%   performance. The 
%
% (c) Seyed Yahya Shirazi, 03/2023 UCSD, INC, SCCN

%% initialize and adding paths
clearvars -except participant_list platform machine load_setfiles save_setfiles
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
if ~exist('load_setfiles','var') || isempty(load_setfiles), load_setfiles = false; end
if ~exist('save_setfiles','var') || isempty(save_setfiles), save_setfiles = true; end
f2l.elocs = p2l.codebase + "funcs" + fs + "GSN_HydroCel_129_AdjustedLabels.sfp";

%% load ICA_structs
unavailable_participants = [];
for p = participant_list
    p2l.incr0 = p2l.eegRepo + p + fs + "ICA" + fs + "incr0" + fs;
    f2l.ICA_STRUCT.(p) = p2l.incr0 + p + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
    try
        temp_file = load(f2l.ICA_STRUCT.(p), "temp_ict");
        ICA_STRUCT.(p) = temp_file.temp_ict;
    catch
        unavailable_participants = [unavailable_participants p];
        participant_list(participant_list==p) = [];
    end
end

%% load EEG files as well
if load_setfiles
    f = waitbar(0,'updating the set files with frame rejections','Name','please be patient');
    for p = participant_list
        p2l.EEGsets.(p) = p2l.eegRepo+ p + fs + "EEG_sets" + fs; % Where .set files are saved
        f2l.alltasks.(p) = p + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
        f2l.alltasks_cleaned.(p) = p + "_" + mergedSetName + "_stepwiseCleaned.set";
        %     if ~exist(p2l.EEGsets.(p) + f2l.alltasks_cleaned.(p), 'file')
        EEG = [];
        EEG = pop_loadset( 'filename', char(f2l.alltasks.(p)), 'filepath', char(p2l.EEGsets.(p)));
        EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
        
        % Update to concatenated data w/o frame rejection
        EEG = update_EEG(EEG, ICA_STRUCT.(p), false, 1, true);
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
        %     end
        waitbar(find(participant_list==p)/length(participant_list),f)
    end
    close(f)
end

%% now let's run ICLABEL on the datasets, and augment ICA_STRUCT
f = waitbar(0,'adding iclabel','Name','please be patient');
for p = participant_list
    if ~isfield(ICA_STRUCT.(p), 'iclabel')
        EEG = [];
        EEG = pop_loadset( 'filename', char(f2l.alltasks_cleaned.(p)), 'filepath', char(p2l.EEGsets.(p)));
        EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
        EEG.nbchans = length(EEG.chanlocs);
        EEG = eeg_checkset(EEG);
        
        EEG = iclabel(EEG, 'default');
        EEG = talLookup(EEG);
        ICA_STRUCT.(p).iclabel = EEG.etc.ic_classification;
        ICA_STRUCT.(p).tal_dipfit = EEG.dipfit;
        temp_ict = ICA_STRUCT.(p);
        if save_setfiles
            save(f2l.ICA_STRUCT.(p), "temp_ict")
        end
    end
    waitbar(find(participant_list==p)/length(participant_list),f)
end
close(f)

%% aggregate coarse metrics
rej_elec_count = [];
rej_frame_ratio = [];
k = [];
incr_number = [];
braincomps = struct;
braincomp_count = struct;
original_numchans = 128; 
for p = participant_list
    rej_elec_count(end+1) = original_numchans-length(ICA_STRUCT.(p).good_chans);
    rej_chans.(p) = setdiff(1:128,ICA_STRUCT.(p).good_chans);
    rej_frame_ratio(end+1) = ICA_STRUCT.(p).percent_frames_bad;
    k(end+1) = ICA_STRUCT.(p).k;
    incr_number(end+1) = ICA_STRUCT.(p).most_brain_increments.selected_incr;

    braincomps.(p).ninety = find(ICA_STRUCT.(p).iclabel.ICLabel.classifications(:,1)>0.9);
    braincomps.(p).eighty = find(ICA_STRUCT.(p).iclabel.ICLabel.classifications(:,1)>0.8);
    braincomps.(p).seventy = find(ICA_STRUCT.(p).iclabel.ICLabel.classifications(:,1)>0.7);
    braincomps.(p).sixty = find(ICA_STRUCT.(p).iclabel.ICLabel.classifications(:,1)>0.6);
    braincomp_count.ninety(participant_list==p) = length(braincomps.(p).ninety);
    braincomp_count.eighty(participant_list==p) = length(braincomps.(p).eighty);
    braincomp_count.seventy(participant_list==p) = length(braincomps.(p).seventy);
    braincomp_count.sixty(participant_list==p) = length(braincomps.(p).sixty);
end

%% number of brain components
figure
boxplot([braincomp_count.ninety', braincomp_count.eighty', braincomp_count.seventy', braincomp_count.sixty'],'Notch','on','Labels',{'90%', '80%', '70%', '60%'},'Whisker',1)
title('number of brain components per ICLABEL classification')
xlabel("probability of the dipole being Brain")
ylabel("number of dipoles")

%% Brodmann area distibution of the brian components


%% number of rejected elecrtods
figure
boxplot(rej_elec_count,'Notch','on','Labels',{'number of rejected electrode'},'Whisker',1)
title('Rejected electrodes numbers')
% xlabel("probability of the dipole being Brain")
% ylabel("number of dipoles")

%% rejected electrode topoplot
% load a dummy EEG file
EEG = pop_loadset('filename','NDARAA948VFH_everyEEG.set','filepath','~/HBN_EEG/NDARAA948VFH/EEG_sets/');
EEG = pop_select(EEG, 'nochannel',129);
rej_count = zeros(1, original_numchans);
for p = string(fieldnames(rej_chans))'
    rej_count(rej_chans.(p)) = rej_count(rej_chans.(p)) + 1;
end
rej_count = rej_count * 5; % make the dots a little larger.

cl = floor((rej_count-min(rej_count)+1) /range(rej_count) * 255);
cl(cl>255) = 255;
cl(cl==0) = 1;
cmap = cool(255);

figure('Renderer','painters')
colormap cool
mod_topoplot([],EEG.chanlocs,'electrodes','on','emarker',{1:EEG.nbchan,'.',cmap(cl,:),rej_count,1})
colorbar
%% amount of frame rejection
figure
boxplot(rej_frame_ratio,'Notch','on','Labels',{'Rejected frame percentage'},'Whisker',1)
title('Rejected frame percentage')
