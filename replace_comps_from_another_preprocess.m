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