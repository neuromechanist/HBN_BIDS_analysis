%% paths
addpath('eeglab')
addpath(genpath('HBN_BIDS_analysis'))
eeglab; close;
study_path = "/home/sshirazi/yahya/cmi_bids_R3_RC3/";
out_path = study_path + "derivatives/eeglab_test/";
ica_path = out_path + "amica_tmp/";
mkdir(ica_path)
%% load the bids dataset
[STUDY, ALLEEG] = pop_importbids(char(study_path), 'eventtype','value','bidsevent','on','bidschanloc','off',...
    'outputdir',char(out_path),'bidstask','surroundSupp', 'studyName','surroundSupp');
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% Keep only the datasets with avaialble tag
available_idx = lookup_dataset_info(STUDY, 1, [1, 2], ["surroundSupp_1", "surroundSupp_2"], "available", "subject");

% only keep dataset indices with both runs available
available_subjs = intersect(string(available_idx{1}), string(available_idx{2}));

% keep only available subjects
[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs)});
EEG = ALLEEG;

%% save study
[STUDY ALLEEG] = std_editset( STUDY, ALLEEG, 'name','Surround Suppression');
[STUDY EEG] = pop_savestudy( STUDY, EEG, 'savemode','resavegui','resavedatasets','on');
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% clean channel data
EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion','off','ChannelCriterion',0.8,'LineNoiseCriterion',5,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian','fusechanrej',1);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, [1:length(EEG)] ,'study',1); 
STUDY = std_checkset(STUDY, ALLEEG);

[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% concatenate same-subject/task runs and run AMICA
parfor (s = 1:length(available_subjs), 24)
    [~, temp_EEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs(s))});
    temp_mergedEEG = pop_mergeset(temp_EEG, 1:length(temp_EEG));

    runamica17_nsg(temp_mergedEEG, 'outdir', char(ica_path+available_subjs(s)),...
        'do_reject', 1, 'numrej', 5, 'rejsig', 4);
end

%% load the ICA weights
% find the EEG data for each subject and update the weights.
EEG_subjs = string({EEG(:).subject});
for s = available_subjs
    idx = find(EEG_subjs==s);
    for i = idx
        EEG(i) = eeg_loadamica(EEG(i), char(ica_path + s), 1);
    end
end

[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% Perform dipfit
elocs = "GSN_HydroCel_129_AdjustedLabels.sfp";
HDM = "eeglab/plugins/dipfit5.4/standard_BEM/standard_vol.mat";
MRI = "eeglab/plugins/dipfit5.4/standard_BEM/standard_mri.mat";
chan = "eeglab/plugins/dipfit5.4/standard_BEM/elec/standard_1005.elc";

for e = 1:length(EEG)
    EEG(e) = pop_dipfit_settings(EEG(e), 'hdmfile', char(HDM), 'mrifile', char(MRI),...
        'chanfile', char(chan), 'coordformat', 'MNI', 'chansel', 1:EEG(e).nbchan);
    [~,EEG(e).dipfit.coord_transform] = coregister(EEG(e).chanlocs,EEG(e).dipfit.chanfile,...
        'chaninfo1', EEG(e).chaninfo,'mesh',EEG(e).dipfit.hdmfile, 'manual', 'off');

    EEG(e) = pop_multifit(EEG(e), [] , 'threshold',100, 'plotopt',{'normlen', 'on'});
end
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% run ICLABEL
EEG = pop_iclabel(EEG, 'default');
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'savemode','resavegui','resavedatasets','on');


%% Epoch
EEG = pop_epoch( EEG,{'fixpoint_ON','stim_ON'},[-1 3.5] ,'epochinfo','yes');
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, [1:264] ,'study',1); 
STUDY = std_checkset(STUDY, ALLEEG);

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename','surroundSupp_epoched.study','filepath','/expanse/projects/nemar/yahya/cmi_bids_R3_RC3/derivatives/eeglab_test/');
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% precompute
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','scalp','on','spec','on','specparams', {'specmode', 'psd', 'logtrials', 'off', 'freqrange',[3 80]},'recompute','on');

%%
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','scalp','on','ersp','on','spec','on','erspparams',{'cycles',[3 0.5],'alpha',0.05, 'padratio',2,'baseline',NaN,...
    'freqs', [3 100]},'specparams', {'specmode', 'psd', 'logtrials', 'off', 'freqrange',[3 80]},'recompute','on');

%% plot the components
clustinfo = table;
clustinfo(1,:) = {3, "VR", rgb('Orange')}; % VR
clustinfo(2,:) = {4, "eye", rgb('Purple')}; % eye
clustinfo(3,:) = {6, "FR", rgb('Cyan')}; % FR
clustinfo(4,:) = {7, "MR", rgb('Lime')}; %MR
clustinfo(5,:) = {8, "VC", rgb('Red')}; %VC
clustinfo(6,:) = {9, "FC", rgb('Blue')}; % FC , SMA
clustinfo(7,:) = {11, "ML", rgb('Teal')}; %ML
clustinfo(8,:) = {13, "VR2", rgb('OrangeRed')}; %VR
% clustinfo(9,:) = {14, "", rgb('Orange')};
clustinfo(9,:) = {16, "FL", rgb('DeepSkyBlue')}; %FL
clustinfo(10,:) = {17, "MC", rgb('Green')}; %MC
clustinfo(11,:) = {18, "VL", rgb('DeepPink')}; %VL

clustinfo.Properties.VariableNames = ["num","BA","color"];

%% now really plot

fig = diplotfig(STUDY, ALLEEG,transpose([clustinfo.num]),...
        num2cell(clustinfo.color,2) ,1,'view',[1 -1 1],'gui','off','newfig','on'); 