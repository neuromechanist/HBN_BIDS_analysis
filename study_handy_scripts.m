%% paths
addpath('eeglab')
addpath(genpath('HBN_BIDS_analysis'))
eeglab; close;
study_path = "/home/sshirazi/yahya/cmi_bids_R3_RC2/";
out_path = study_path + "derivatives/eeglab_test_redo/";
ica_path = out_path + "amica_tmp/";
mkdir(ica_path)

new_study = 0; % set it to 1 to load the data  from scratch
% ion order to have a more robust ICA, tasks groups can concatenate the data, but later, only the target task will be analyzed.
task_group = ["surroundSupp"    "RestingState"    "DespicableMe"    "ThePresent"    "FunwithFractals"    "DiaryOfAWimpyKid"];
target_task = "surroundSupp";
%% load the bids dataset
if new_study
    [STUDY, ALLEEG] = pop_importbids(char(study_path), 'eventtype','value','bidsevent','on','bidschanloc','off', 'outputdir',char(out_path),...
        'bidstask', cellstr(task_group), 'studyName','surroundSupp');
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
else
% or alternatively load the study
    [STUDY ALLEEG] = pop_loadstudy('filename', 'surroundSupp.study', 'filepath', char(out_path));
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
end

% Identify datasets with avaialble tag
available_idx = lookup_dataset_info(STUDY, 1, [1, 2], ["surroundSupp_1", "surroundSupp_2"], "available", "subject");

available_subjs = intersect(string(available_idx{1}), string(available_idx{2}));

%% keep only available subjects
[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs)});
EEG = ALLEEG;

%% save study
[STUDY ALLEEG] = std_editset(STUDY, ALLEEG, 'name','Surround Suppression');
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui','resavedatasets','on');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% clean channel data
pop_editoptions('option_parallel', 1);
EEG = pop_eegfiltnew(EEG, 1, 0); % Highpass at 1 Hz, and Lowpass 0 Hz.

EEG = pop_cleanline(EEG, 'bandwidth',2,'chanlist',1:128,...
        'computepower',1,'linefreqs',[60 120 180] ,'normSpectrum',0,'p',0.05,'pad',2,'plotfigures',0,...
        'scanforlines',1,'sigtype','Channels','tau',100,'verb',1,'winsize',4,'winstep',1, 'newversion', true);
EEG = pop_cleanline(EEG, 'bandwidth',2,'chanlist',1:128,...
        'computepower',1,'linefreqs',[60 120 180] ,'normSpectrum',0,'p',0.05,'pad',2,'plotfigures',0,...
        'scanforlines',1,'sigtype','Channels','tau',100,'verb',1,'winsize',4,'winstep',1, 'newversion', true);

EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion','off','ChannelCriterion',0.8,'LineNoiseCriterion',5,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian','fusechanrej',1);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, [1:length(EEG)] ,'study',1); 
STUDY = std_checkset(STUDY, ALLEEG);

[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
CURRENTSTUDY = 1; ALLEG = EEG; CURRENTSET = [1:length(EEG)];

%% concatenate same-subject/task runs and run AMICA
parfor (s = 1:length(available_subjs), 24)
    [~, temp_EEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs(s))});
    temp_mergedEEG = pop_mergeset(temp_EEG, 1:length(temp_EEG));

    runamica17_nsg(temp_mergedEEG, 'outdir', char(ica_path+available_subjs(s)),...
        'do_reject', 1, 'numrej', 5, 'rejsig', 4);
end

%% Check if AMICA redsults exists and re-run AMICA
% Current AMICA may freeze in 5 to 10% of the cases. Therefore, we need to
% ensure that were completed.
for s = 1:length(available_subjs)
    if ~exist(ica_path+available_subjs(s), "dir") || ~exist(ica_path+available_subjs(s)+"/W", "file")
        warning("AMICA did not run for subject "+available_subjs(s)+", trying to rerun AMICA!")
        [~, temp_EEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs(s))});
        temp_mergedEEG = pop_mergeset(temp_EEG, 1:length(temp_EEG));

        runamica17_nsg(temp_mergedEEG, 'outdir', char(ica_path+available_subjs(s)),...
            'do_reject', 1, 'numrej', 5, 'rejsig', 4);
    end
end

%% load the ICA weights
% find the EEG data for each subject and update the weights.
unav_amica = [];
EEG_subjs = string({EEG(:).subject});
for s = available_subjs
    try
        idx = find(EEG_subjs==s);
        for i = idx
            EEG(i) = eeg_loadamica(EEG(i), char(ica_path + s), 1);
        end
    catch
        unav_amica = [unav_amica s]; %#ok<AGROW> 
    end
end

[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% Perform dipfit
elocs = "GSN_HydroCel_129_AdjustedLabels.sfp";
HDM = "eeglab/plugins/dipfit5.4/standard_BEM/standard_vol.mat";
MRI = "eeglab/plugins/dipfit5.4/standard_BEM/standard_mri.mat";
chan = "eeglab/plugins/dipfit5.4/standard_BEM/elec/standard_1005.elc";
EEG_subjs = string({EEG(:).subject});

for s = available_subjs
    idx = find(EEG_subjs==s);
    for i = idx
        if i == idx(1) % run dipfit
            EEG(i) = pop_dipfit_settings(EEG(i), 'hdmfile', char(HDM), 'mrifile', char(MRI),...
                'chanfile', char(chan), 'coordformat', 'MNI', 'chansel', 1:EEG(i).nbchan);
            [~,EEG(i).dipfit.coord_transform] = coregister(EEG(i).chanlocs,EEG(i).dipfit.chanfile,...
                'chaninfo1', EEG(i).chaninfo,'mesh',EEG(i).dipfit.hdmfile, 'manual', 'off');
        
            EEG(i) = pop_multifit(EEG(i), [] , 'threshold',100, 'plotopt',{'normlen', 'on'});
        else
            EEG(i).dipfit = EEG(idx(1)).dipfit;

            % also save the structure for later use
            dipfit = EEG(i).dipfit;
            save(ica_path+s+string(filesep)+s+"_dipfit.mat", "-struct", "dipfit");
        end
    end
end
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

%% run ICLABEL
pop_editoptions('option_parallel', 0);
EEG = pop_iclabel(EEG, 'default');

[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

%% ICLABEL rejection
pop_editoptions( 'option_parallel', 0);
EEG = pop_icflag(EEG, [0 0.59;0 NaN;NaN NaN;NaN NaN;NaN NaN;NaN NaN;NaN NaN]);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
% Check if there is a subject with all comps rejected, then we shoul remove
% that subject

EEG_subjs = unique(string({EEG(:).subject}));
nobrain_subjs = [];
for s = EEG_subjs
    idx = find(string({EEG(:).subject})==s);
    for i = idx
        if isempty(find(EEG(i).reject.gcompreject == 0))
            warning("subject " + s + " does not have any Brain comps according to ICLABEL, removing the subjs from STUDY")
            nobrain_subjs = [nobrain_subjs, s];
            break;
        end
        STUDY.datasetinfo(i).comps = find(EEG(i).reject.gcompreject == 0)';
    end    
end
if ~isempty(nobrain_subjs)
    [STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'rmvarvalues', {'subject', cellstr(nobrain_subjs)});
end
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(ALLEEG, 1:length(ALLEEG));
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'resavedatasets', 'on');

% Let's see how many components will remain
% this checks EEG.reject structure
kept_comps = [];
for i = 1:length(EEG)
    kept_comps = [kept_comps length(find(EEG(i).reject.gcompreject==0))];
end
disp("total kept comps in EEG.reject:" + sum(kept_comps)/length(STUDY.run) + ", mean:" + string(mean(kept_comps)) +", std:"+ string(std(kept_comps)));

% this checks datasetinfo
kept_comps = [];
for i = 1:length(EEG)
    kept_comps = [kept_comps length(STUDY.datasetinfo(i).comps)];
end
disp("total kept comps in datasetinfo:" + sum(kept_comps)/length(STUDY.run) + ", mean:" + string(mean(kept_comps)) +", std:"+ string(std(kept_comps)));

%% Create a new study if task_group and target_task are not the same
surround_idx = lookup_dataset_info(STUDY, 1 , [1, 2], ["task", "task"], "surroundSupp");
surround_idx = union(cell2mat(surround_idx{1}), cell2mat(surround_idx{2}));
all_idx = [STUDY.datasetinfo(:).index];

rmv_idx = all_idx(~ismember(all_idx, surround_idx));

[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'datinds', rmv_idx);
EEG = ALLEEG;
STUDY = std_checkset(STUDY, ALLEEG);

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename','surroundSupp_summarized.study','filepath',char(out_path), 'resavedatasets', 'on');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% Epoch
% First identify target_task index

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename','surroundSupp_epoched.study','filepath',char(out_path), 'resavedatasets', 'on');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

EEG = pop_epoch( EEG,{'fixpoint_ON','stim_ON'},[-1 2] ,'epochinfo','yes');

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'resavedatasets', 'on');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

%% precompute
pop_editoptions('option_parallel', 1);
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','spec','on','allcomps', 'on', 'specparams', {'specmode', 'psd', 'logtrials', 'off', 'freqrange',[3 80]},'recompute','on');

%% 
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','scalp','on', 'allcomps', 'on', 'recompute','on');
%%
pop_editoptions('option_parallel', 1);
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','ersp','on','allcomps', 'on', 'erspparams',{'cycles',[3 0.5],'alpha',0.05, 'padratio',2,'baseline',NaN,...
    'freqs', [3 100]},'recompute','on');

%% create preclutering array
STUDY = std_createclust(STUDY, ALLEEG, 'parentcluster', 'on');  % Update the parent cluster array, especially required if componenets have been changed.
[STUDY ALLEEG] = std_preclust(STUDY, ALLEEG, 1,...
    {'spec','npca',3,'weight',1,'freqrange',[3 70] },...
    {'scalpLaplac','npca',3,'weight',1,'abso',0},...
    {'dipoles','weight',10},'parentclust');
%% plot the components
clustinfo = table;
clustinfo(1,:) = {6, "BA4", rgb('Brown')}; % VR
clustinfo(2,:) = {9, "BA6", rgb('Purple')}; % eye
clustinfo(3,:) = {11, "BA6-L Lateral", rgb('Cyan')}; % FR
clustinfo(4,:) = {12, "BA4 Lateral", rgb('Lime')}; %MR
clustinfo(5,:) = {16, "BA10", rgb('Red')}; %VC
clustinfo(6,:) = {18, "BA6-L", rgb('Blue')}; % FC , SMA
clustinfo(7,:) = {23, "BA6-R", rgb('Teal')}; %ML

clustinfo.Properties.VariableNames = ["num","BA","color"];

%% now really plot

fig = diplotfig(STUDY, ALLEEG,transpose([clustinfo.num]),...
        num2cell(clustinfo.color,2) ,1,'view',[1 -1 1],'gui','off'); 
