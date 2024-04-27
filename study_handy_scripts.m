%% paths
addpath('eeglab')
addpath(genpath('HBN_BIDS_analysis'))
eeglab; close;
study_path = "/home/sshirazi/yahya/cmi_bids_R3_RC3/";
out_path = study_path + "derivatives/eeglab_test/";

%% load the bids dataset
[STUDY, ALLEEG] = pop_importbids(char(study_path), 'eventtype','value','bidsevent','on','bidschanloc','off',...
    'outputdir',char(out_path),'bidstask','surroundSupp', 'studyName','surroundSupp');
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% Keep only the datasets with avaialble tag
available_idx = lookup_dataset_info(STUDY, ["surroundSupp_1", "surroundSupp_2"], "available");

% only keep dataset indices with both runs available
available_idx = intersect(cell2mat(available_idx{1}), cell2mat(available_idx{2}));

% get the subject id
available_subjs = unique({STUDY.datasetinfo(ismember([STUDY.datasetinfo(:).index],available_idx)).subject});

% keep only available subjects
[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', available_subjs});

%% clean channel data
EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion','off','ChannelCriterion',0.8,'LineNoiseCriterion',5,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian','fusechanrej',1);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, [1:291] ,'study',1); 
STUDY = std_checkset(STUDY, ALLEEG);

%% change the event type  % not needed for the new datasets.
for e = 1:length(EEG)
    EEG(e) = replace_event_type(EEG(e));
end

%% can we expand in place? % The case of the Present
expand_table = "the_present_stimulus-LogLumRatio.tsv";
for e = 1:length(EEG)
    EEG(e) = expand_events(EEG(e), expand_table, ["shot_number", "LLR"],'shots', 0, 1);
end
ALLEEG = EEG;

%% update the components
p2l = init_paths("linux", "expanse", "HBN", 0, false);
fs = string(filesep)+string(filesep);
mergedSetName = "everyEEG";
subj_list = string({STUDY.datasetinfo.subject});
subjs = squeeze(split(subj_list,"-")); subjs = subjs(:,2);
% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'retrieve',[1:291] ,'study',1); CURRENTSTUDY = 1;

    %% first check if the ICA_STRUCT is there
i = 1;
unav_datasets = [];
unav_datasets_idx = [];
for s = subjs'
     p2l.incr0 = p2l.eegRepo + s + fs + "ICA" + fs + "incr0" + fs;
     f2l.ICA_STRUCT.(s) = p2l.incr0 + s + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
     try
        ICA_STRUCT.(s) = load(f2l.ICA_STRUCT.(s));
     catch
         unav_datasets = [unav_datasets s];
         unav_datasets_idx = [unav_datasets_idx i];
         warning("data is not present for subject " + s)
     end
     i = i+1;
end

    %% remove datasets without ICA_STRUCT
[STUDY, EEG] = std_editset(STUDY, EEG, 'commands', {{'remove' unav_datasets_idx}}, 'updatedat', 'on');
ALLEEG = EEG;

%% update the EEG files with the ICA structure
subj_list = string({STUDY.datasetinfo.subject});
subjs = squeeze(split(subj_list,"-")); subjs = subjs(:,2);
for i = 1:length(subjs)
    s = subjs(i);
    EEG(i) = update_EEG(EEG(i),ICA_STRUCT.(s));

end
ALLEEG = EEG;

%% update the components
% The following for loop only works because there is one dataset per subj.
f = waitbar(0,'Updating studies w/ ICLABEL comps','Name','please be very patient');
for i = 1:length(subjs)
    s = subjs(i);
    [STUDY, EEG] = std_editset(STUDY, EEG, 'commands', {{'index' i ...
        'comps' ICA_STRUCT.(s).incr_comps}});

    
    waitbar(i/length(subjs'),f)
end
close(f);
% ALLEEG = EEG;

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