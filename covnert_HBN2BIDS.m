%% Convert HBN data to BIDS
% This script convert the list of specified tasks |task_list| to a BIDS dataset 
% uising EEGLAB's |bids_export|. Only the subjects whithin the defined |release| 
% and having all the datasets included in the |task_list| will be included in 
% the BIDS dataset.
% 
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% Initialize
clearvars

target_release = "all";%["R3"]; %#ok<NBRAK2> 
num_subjects = -1; % if -1, all subjects in the release will be added.

p2l = init_paths("linux", "expanse", "HBN", 1, 1);
f2l.elocs = p2l.eegRepo + "GSN_HydroCel_129.sfp";  % f2l = file to load

plist = readtable("./funcs/tsv/participants_augmented_filesize.tsv", "FileType","text");
plist.Full_Pheno = string(plist{:,"Full_Pheno"}); % to change the variable type to string
plist.Commercial_Use = string(plist{:,"Commercial_Use"});
plist.Sex = string(plist{:,"Sex"});
plist.Sex(plist.Sex=="1") = "F"; plist.Sex(plist.Sex=="0") = "M";
datarepo = "~/yahya/HBN_fulldataset/";
remediedrepo = "~/yahya/HBN/vidBIDS_test/";
dpath = "/EEG/raw/mat_format/"; % downstream path after the subject
fnames = readtable("funcs/tsv/filenames.tsv", "FileType","text"); % file names, this table is compatible with `tnames`
bids_export_path = "~/yahya/cmi_bids_R1-R11/";
addpath(genpath(p2l.codebase))
no_subj_info_cols = 8; % 
tnames = string(plist.Properties.VariableNames); % task names
tnames = tnames(no_subj_info_cols+1:end);
clear EEG

%% Define tasks
% Let's also define the tasks and potentially the release that we want to include 
% in the BIDS
% target_tasks = ["Video_TP"]; BIDS_task_name = ["ThePresent"]; % in case of a single task 
target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK", ...
    "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3",...
    "SurroundSupp_Block1", "SurroundSupp_Block2", "vis_learn", "WISC_ProcSpeed"];
BIDS_task_name = {'RestingState', 'DespicableMe', 'FunwithFractals', 'ThePresent', 'DiaryOfAWimpyKid',...
    'contrastChangeDetection', 'contrastChangeDetection', 'contrastChangeDetection', ...
    'surroundSupp', 'surroundSupp', 'seqLearning', 'symbolSearch'};
BIDS_run_seq = [nan,nan,nan,nan,nan,...
    1,2,3,...
    1,2,nan,nan];
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
req_info = [base_info, target_tasks]; target_info = [base_info, BIDS_task_name];

%% define the pInfo descriptions
pInfo_desc.participant_id.Description = 'The prticipant ID set in the HBN dataset';
pInfo_desc.release_number.Description = 'The release in which the dataset was made available via the HBN project';
pInfo_desc.sex.LongName = 'Gender'; pInfo_desc.sex.Description = 'Gender';
pInfo_desc.sex.Levels.F = 'Female'; pInfo_desc.sex.Levels.M = 'Male' ;
pInfo_desc.age.LongName = 'Age'; pInfo_desc.age.Description = 'Age in years';
pInfo_desc.ehq_total.LongName = 'Handedness';
pInfo_desc.ehq_total.Description = 'Edinburgh Handedness Questionnaire, +100=Fully Right-handed, -100=Fully Left-handed';
pInfo_desc.commercial_use.Description = 'Did the participant consent to commercial use of data?';
pInfo_desc.commercial_use.Levels.Yes = 'Subject gave consent to commercial use of data';
pInfo_desc.commercial_use.Levels.No = 'Subject did not give consent to commercial use of data';
pInfo_desc.full_pheno.Description = 'Does the participant have a full phenotypic file?';
pInfo_desc.full_pheno.levels.Yes = 'Subject has full phenotypic file';
pInfo_desc.full_pheno.levels.No = 'Subject does not have full phenotypic file';

pInfo_desc.RestingState.Description = 'File size of the resting-state trial in (kB)';
pInfo_desc.DespicableMe.Description = 'File size of watching the Despicable Me trial (kB)';
pInfo_desc.FunwithFractals.Description = 'File size of watching the Fun with Fractals trial (kB)';
pInfo_desc.ThePresent.Description = 'File size of watching the The Present trial (kB)';
pInfo_desc.DiaryOfAWimpyKid.Description = 'File size of watching the Diary Of A Wimpy Kid trial (kB)';
pInfo_desc.contrastChangeDetection_1.Description = 'File size of the 1st run of the contrast change task (KB)';
pInfo_desc.contrastChangeDetection_2.Description = 'File size of the 2nd run of the contrast change task (KB)';
pInfo_desc.contrastChangeDetection_3.Description = 'File size of the 3rd run of the contrast change task (KB)';
pInfo_desc.surroundSupp_1.Description = 'File size of the 1st run of the surround suppression task (KB)';
pInfo_desc.surroundSupp_2.Description = 'File size of the 2nd run of the surround suppression task (KB)';
pInfo_desc.seqLearning.Description = 'File size of the sequence learning task (KB)';
pInfo_desc.symbolSearch.Description = 'File size of the symbol search task (KB)';

%% Create the structure as required by EEGLAB's bids export.
% While the files are not remedied and are not on EEGLAB's format, it is good 
% to have the strucutre to later on use it for adjusting the raw files and then 
% making the structure.
data = struct;
pInfo = cellstr([lower(["participant_id","release_number","Sex","Age","EHQ_Total","Commercial_Use","Full_Pheno"]), ...
    BIDS_set_name]);
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
for i = 1:length(data)
    try
        EEG = [];
        subj = string(data(i).subject);
        eeg_set_names = data(i).set_name;
        for n = eeg_set_names
            p2l.rawEEG = datarepo + string(data(i).subject) + dpath;
            tempload = load(p2l.rawEEG + data(i).raw_file(n==eeg_set_names));
            EEG.(n) = tempload.EEG;
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
        EEG.(n) = augment_behavior_events(EEG.(n), behavior_dir);
        EEG.(n) = eeg_checkset(EEG.(n), 'makeur');
        EEG.(n) = eeg_checkset(EEG.(n), 'chanlocs_homogeneous');
        % save the remedied EEG structure.
        pop_saveset(EEG.(n), 'filename', char(n), 'filepath', char(p2l.rawEEG_updated));
        disp("saved the remedied file for" + n)
    end
    catch
        unav_dataset = [unav_dataset, string(data(i).subject)];
        unav_dataset_idx = [unav_dataset_idx i];
        warning("data from " +string(data(i).subject)+" is not available, removing corresponding entries")   
    end       
end
pInfo(unav_dataset_idx+1,:) = []; data(unav_dataset_idx) = [];
%% Now we probably can call bids_export
% keep only relevant information in pInfo_desc
pInfo_fields = string(fieldnames(pInfo_desc))'; undesired_pInfo_field = pInfo_fields(~contains(pInfo_fields,target_info,'IgnoreCase',true));
pInfo_desc = rmfield(pInfo_desc,undesired_pInfo_field);
bids_export(data, 'targetdir', char(bids_export_path), 'pInfo', pInfo, 'pInfoDesc', pInfo_desc, 'tInfo', tInfo);
