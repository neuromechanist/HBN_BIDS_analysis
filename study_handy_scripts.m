study_path = "C:\Users\syshirazi\GDrives\ucsd\My Drive\to share\HBN data\cmi_bids_R3_20\";
out_path = study_path + "derivatives\eeglab_tetst\";

[STUDY, ALLEEG] = pop_importbids(char(study_path), 'eventtype','value','bidsevent','on','bidschanloc','on',...
    'outputdir',char(out_path),'bidstask','ThePresent');

%% change the event type
for e = 1:length(EEG)
    EEG(e) = replace_event_type(EEG(e));
end

%% can we expand in place?
expand_table = "the_present_stimulus-LogLumRatio.tsv";
for e = 1:length(EEG)
    EEG(e) = expand_events(EEG(e), expand_table, ["shot_number", "LLR"],'shots');
end
ALLEEG = EEG;

%% update the components
% init_paths("linux", "expanse", "HBN", 1, false);
fs = string(filesep)+string(filesep);
mergedSetName = "videoEEG";
subj_list = string({STUDY.datasetinfo.subject});
subjs = squeeze(split(subj_list,"-")); subjs = subjs(:,2);

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
     end
     i = i+1;
end

%% remove datasets without ICA_STRUCT
[STUDY, EEG] = std_editset(STUDY, EEG, 'commands', {{'remove' unav_datasets_idx}}, 'updatedat', 'off');
ALLEEG = EEG;

%% update the components
subj_list = string({STUDY.datasetinfo.subject});
subjs = squeeze(split(subj_list,"-")); subjs = subjs(:,2);

% The following for loop only works because there is one dataset per subj.
f = waitbar(0,'Updating stduies w/ ICLABEL comps','Name','please be very patient');
for i = 1:length(subjs')
    [STUDY, EEG] = std_editset(STUDY, EEG, 'commands', {{'index' i ...
        'comps' ICA_STRUCT.(s).incr_comps}});
    
    waitbar(i/length(subjs'),f)
end
close(f);
ALLEEG = EEG;

