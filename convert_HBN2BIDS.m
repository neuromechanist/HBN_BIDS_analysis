function convert_HBN2BIDS(target_tasks)
%CONVERT_HBN2BIDS Convert HBN data to BIDS
% This script convert the list of specified tasks |task_list| to a BIDS dataset 
% uising EEGLAB's |bids_export|. Only the subjects whithin the defined |release| 
% and having all the datasets included in the |task_list| will be included in 
% the BIDS dataset.
% 
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% Initialize
clearvars -except target_tasks

if ~exist("target_tasks","var") || isempty(target_tasks)
    target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK", ...
    "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3",...
    "SurroundSupp_Block1", "SurroundSupp_Block2", "vis_learn", "WISC_ProcSpeed"];
end

target_release = ["R3"]; %#ok<NBRAK2> 
num_subjects = 22; % if -1, all subjects in the release will be added.

p2l = init_paths("linux", "sccn", "HBN", 1, 1);
addpath(genpath(p2l.codebase))
f2l.elocs = p2l.eegRepo + "GSN_HydroCel_129.sfp";  % f2l = file to load

plist = readtable("participants_augmented_filesize.tsv", "FileType","text");
plist.Full_Pheno = string(plist{:,"Full_Pheno"}); % to change the variable type to string
plist.Commercial_Use = string(plist{:,"Commercial_Use"});
plist.Sex = string(plist{:,"Sex"});
plist.Sex(plist.Sex=="1") = "F"; plist.Sex(plist.Sex=="0") = "M";
remediedrepo = p2l.temp + "/taskBIDS_test/";
dpath = "/EEG/raw/mat_format/"; % downstream path after the subject
fnames = readtable("funcs/tsv/filenames.tsv", "FileType","text"); % file names, this table is compatible with `tnames`
bids_export_path = p2l.yahya + "/cmi_bids_R3_20/";
no_subj_info_cols = 8; % 
tnames = string(plist.Properties.VariableNames); % task names
tnames = tnames(no_subj_info_cols+1:end);
clear EEG

%% Define tasks
% Define the BIDS-name couterpart and run numbers
bids_table = readtable("task_bids_conversion.tsv","FileType","text");
BIDS_task_name = bids_table{logical(sum(target_tasks == bids_table{:,"init_name"},2)),"BIDS_name"}';
BIDS_run_seq = bids_table{logical(sum(target_tasks == bids_table{:,"init_name"},2)),"run_num"}';

for i = 1:length(BIDS_task_name)
    if isnan(BIDS_run_seq(i))
        BIDS_set_name(i) = string(BIDS_task_name(i));
    else
        BIDS_set_name(i) = string(BIDS_task_name(i)) + "_" + string(BIDS_run_seq(i));
    end
end
max_allowed_missing_dataset = length(BIDS_set_name)-1; % effectively letting any subkect with as few as one run to be included

% Fields are all in lower case, follwing the BIDS convention
base_info = ["participant_id","release_number","Sex","Age","EHQ_Total","Commercial_Use","Full_Pheno"];
req_info = [base_info, target_tasks];

%% define the pInfo descriptions, eInfo, and eInfo descriptionsdbquit
pInfo_desc = struct();
for i = lower(base_info)
    temp = load("participant_info_descriptions.mat", i);
    pInfo_desc.(i) = temp.(i);
end
set_name_with_dim = [];
for i = BIDS_set_name
    snwd = i + "_in_kB";
    temp = load("participant_info_descriptions.mat", i);
    pInfo_desc.(snwd) = temp.(i);
    set_name_with_dim = [set_name_with_dim snwd];
end

eInfo = {};
if length(unique(string(BIDS_task_name))) == 1  % eInfo can't be for more than ONE task
    temp = load("event_information.mat",unique(string(BIDS_task_name)));
    eInfo = temp.(unique(string(BIDS_task_name)));
end

eInfo_desc = load("event_info_descriptions.mat");

%% Create the structure as required by EEGLAB's bids export.
% While the files are not remedied and are not on EEGLAB's format, it is good 
% to have the strucutre to later on use it for adjusting the raw files and then 
% making the structure.
data = struct;
pInfo = cellstr([lower(base_info), set_name_with_dim]);
if target_release == "all"
    target_table = plist;
else
    target_table = plist(any(table2array(plist(:,"release_number"))==target_release,2),:);
end
for r = 1: height(target_table)
    t = target_table(r,:);
    skip_this_row = false;

    if length(find(t{1, target_tasks}==0)) > max_allowed_missing_dataset, skip_this_row = true;
    else, temp_target_tasks = target_tasks(t{1, target_tasks}~=0);
    end
    if ~skip_this_row
        data(end+1).subject = char(t.participant_id);
        remedied_path = remediedrepo + string(t.participant_id) + dpath;
        for g = temp_target_tasks
            data(end).raw_file(g==temp_target_tasks) = string(fnames{string(fnames.FIELD_NAME)==g,"RAW_FILE_NAME"})';
            data(end).file{g==temp_target_tasks} = cellstr(remedied_path + string(fnames{string(fnames.FIELD_NAME)==g,"TARGET_FILE_NAME"})');
        end
        data(end).task = BIDS_task_name(t{1, target_tasks}~=0);
        data(end).run = BIDS_run_seq(t{1, target_tasks}~=0);
        data(end).set_name = BIDS_set_name(t{1, target_tasks}~=0);
        pInfo = [pInfo;cellstr(t{1,req_info})];
    end
    if num_subjects ~= -1, if r > num_subjects; break; end, end
end
data(1) = [];

tInfo.PowerLineFrequency = 60; % task info, it one per experiment.

%% Remedy the files
% This step is simialr to the import and remedy sections of step1.
unav_dataset = [];
unav_dataset_idx = [];
quality_table = table();
for i = 1:length(data)
    try
        EEG = [];
        subj = string(data(i).subject);
        eeg_set_names = data(i).set_name;
        for n = eeg_set_names
            p2l.rawEEG = p2l.raw + string(data(i).subject) + dpath;
            tempload = load(p2l.rawEEG + data(i).raw_file(n==eeg_set_names));
            EEG.(n) = tempload.EEG;
            behavior_dir = p2l.raw + string(data(i).subject) + "/Behavioral/mat_format/";
            disp("loaded "+p2l.rawEEG + data(i).raw_file(n==eeg_set_names))
        end
    
    p2l.rawEEG_updated = remediedrepo + string(data(i).subject) + dpath;
    if ~exist(p2l.rawEEG_updated, "dir"), mkdir(p2l.rawEEG_updated); end
    for n = string(fieldnames(EEG))'
        EEG.(n).setname = char(subj + "_" + n);
        EEG.(n).subject = char(subj);
        EEG.(n) = eeg_checkset(EEG.(n));
        EEG.(n) = pop_chanedit(EEG.(n), 'load', {char(f2l.elocs),'filetype','autodetect'});
        EEG.(n) = pop_chanedit(EEG.(n), 'setref',{'1:129','Cz'});
        [EEG.(n).event.latency] = deal(EEG.(n).event.sample);
        EEG.(n) = replace_event_type(EEG.(n), 'funcs/tsv/lookup_events.tsv', 1);
        EEG.(n) = augment_behavior_events(EEG.(n), data(i).raw_file(n==string(fieldnames(EEG))'), behavior_dir);
        EEG.(n) = eeg_checkset(EEG.(n), 'makeur');
        EEG.(n) = eeg_checkset(EEG.(n), 'chanlocs_homogeneous');
        % save the remedied EEG structure.
        pop_saveset(EEG.(n), 'filename', char(n), 'filepath', char(p2l.rawEEG_updated));
        disp("saved the remedied file for " + n)
    end
    quality_table = run_quality_metrics(EEG, quality_table, 0);
    catch
        unav_dataset = [unav_dataset, string(data(i).subject)];
        unav_dataset_idx = [unav_dataset_idx i];
        warning("data from " +string(data(i).subject)+" is not available, removing corresponding entries")   
    end       
end
pInfo(unav_dataset_idx+1,:) = []; data(unav_dataset_idx) = [];

%% Now we probably can call bids_export
% keep only relevant information in pInfo_desc

task = 'unnamed';
if length(unique(BIDS_task_name)) == 1, task = BIDS_task_name{1}; end
bids_export(data, 'targetdir', char(bids_export_path), 'pInfo', pInfo, 'pInfoDesc', pInfo_desc, 'tInfo', tInfo, ...
    'eInfo', eInfo, 'eInfoDesc', eInfo_desc, 'taskName', task, 'deleteExportDir', 'off');
