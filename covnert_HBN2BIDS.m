%% Convert HBN data to BIDS
% This script convert the list of specified tasks |task_list| to a BIDS dataset 
% uising EEGLAB's |bids_export|. Only the subjects whithin the defined |release| 
% and having all the datasets included in the |task_list| will be included in 
% the BIDS dataset.
% 
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% Initialize
clearvars
p2l = init_paths("linux", "expanse", "HBN", 1, 1);
f2l.elocs = p2l.eegRepo + "GSN_HydroCel_129.sfp";  % f2l = file to load

plist = readtable("./funcs/tsv/participants_augmented_filesize.tsv", "FileType","text");
plist.Full_Pheno = string(plist{:,"Full_Pheno"}); % to change the variable type to string
plist.Commercial_Use = string(plist{:,"Commercial_Use"});
plist.Sex = string(plist{:,"Sex"});
plist.Sex(plist.Sex=="1") = "F"; plist.Sex(plist.Sex=="0") = "M";
datarepo = "~/yahya/HBN_fulldataset/";
remediedrepo = "~/yahya/HBN/vidBIDS/";
dpath = "/EEG/raw/mat_format/"; % downstream path after the subject
fnames = readtable("funcs/tsv/filenames.tsv", "FileType","text"); % file names, this table is compatible with `tnames`
bids_export_path = "~/yahya/cmi_vid_bids_R3_10/";
addpath(genpath(p2l.codebase))
no_subj_inf_cols = 8;
tnames = string(plist.Properties.VariableNames); % task names
tnames = tnames(no_subj_inf_cols+1:end);
clear EEG

%% Define tasks
% Let's also define the tasks and potentially the release that we want to include 
% in the BIDS
target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK"];
task_name_forBIDS = {'RestingState', 'DespicableMe', 'FunwithFractals', 'ThePresent', 'DiaryOfAWimpyKid'};
target_release = ["R3"]; %#ok<NBRAK2> 
num_subjects = 10; % if -1, all subjects in the release will be added.
max_allowed_missing_dataset = 0;

% Fields are all in lower case, follwing the BIDS convention
req_info = ["participant_id","release_number","Sex","Age","EHQ_Total","Commercial_Use","Full_Pheno", ...
    target_tasks];

%% define the pInfo descriptions
pInfo_desc.participant_id.Description = 'The prticipant ID set in the HBN dataset';
pInfo_desc.release_number.Description = 'The release in which the dataset was made avaialbel via the HBN project';
pInfo_desc.sex.LongName = 'Gender'; pInfo_desc.sex.Description = 'Gender';
pInfo_desc.sex.Levels.F = 'Female'; pInfo_desc.sex.Levels.M = 'Male' ;
pInfo_desc.age.LongName = 'Age'; pInfo_desc.age.Description = 'Age in years';
pInfo_desc.ehq_total.LongName = 'Handedness';
pInfo_desc.ehq_total.Description = 'Edinburgh Handedness Questionnair, +100=Fully Right-handed, -100=Fully Left-handed';
pInfo_desc.commercial_use.Description = 'Did the participant consent to commercial use of data?';
pInfo_desc.commercial_use.Levels.Yes = 'Subject gave consent to commercial use of data';
pInfo_desc.commercial_use.Levels.No = 'Subject did not give consent to commercial use of data';
pInfo_desc.full_pheno.Description = 'Does the participant have a full phenotypic file?';
pInfo_desc.full_pheno.levels.Yes = 'Subject has full phenotypic file';
pInfo_desc.full_pheno.levels.No = 'Subject does not have full phenotypic file';

pInfo_desc.RestingState.Description = 'File size of the resting-state trial in (kB)';
pInfo_desc.DespicableMe.Description = 'File size of wathing the Despicable Me trial (kB)';
pInfo_desc.FunwithFractals.Description = 'File size of wathing the Fun with Fractals trial (kB)';
pInfo_desc.ThePresent.Description = 'File size of wathing the The Present trial (kB)';
pInfo_desc.DiaryOfAWimpyKid.Description = 'File size of wathing the Diary Of A Wimpy Kid trial (kB)';



%% Create the structure as required by EEGLAB's bids export.
% While the files are not remedied and are not on EEGLAB's format, it is good 
% to have the strucutre to later on use it for adjusting the raw files and then 
% making the structure.
data = struct;
pInfo = cellstr([lower(["participant_id","release_number","Sex","Age","EHQ_Total","Commercial_Use","Full_Pheno"]), ...
    task_name_forBIDS]);
target_table = plist(string(table2array(plist(:,"release_number")))==target_release,:);
for r = 1: height(target_table)
    t = target_table(r,:);
    skip_this_row = false;

    if length(find(t{1, target_tasks}==0)) > max_allowed_missing_dataset, skip_this_row = true; end
    if ~skip_this_row
        data(end+1).subject = char(t.participant_id);
        remedied_path = remediedrepo + string(t.participant_id) + dpath;
        data(end).raw_file = string(fnames{any(string(fnames.FIELD_NAME)==target_tasks,2),"RAW_FILE_NAME"})';
        data(end).file = cellstr(remedied_path + string(fnames{any(string(fnames.FIELD_NAME)==target_tasks,2),"TARGET_FILE_NAME"})');
        data(end).task = task_name_forBIDS;
        pInfo = [pInfo;cellstr(t{1,req_info})];
    end
    if num_subjects ~= -1, if r > num_subjects; break; end, end
end
data(1) = [];

%% Remedy the files
% This step is simialr to the import and remedy sections of step1.
unav_dataset = [];
unav_dataset_idx = [];
for i = 1:length(data)
    try
    EEG = [];
    subj = string(data(i).subject);
    eeg_files = data(i).raw_file;
    for f = eeg_files
        setname = split(f, ".mat");
        setname = setname(1);
        if contains(setname, "-"), setname = replace(setname, "-", "_"); end
        p2l.rawEEG = datarepo + string(data(i).subject) + dpath;
        tempload = load(p2l.rawEEG + f);
        EEG.(setname) = tempload.EEG;
    end
    
    p2l.rawEEG_updated = remediedrepo + string(data(i).subject) + dpath;
    if ~exist(p2l.rawEEG_updated, "dir"), mkdir(p2l.rawEEG_updated); end
    for f = string(fieldnames(EEG))'
        EEG.(f).setname = char(subj + "_" + f);
        EEG.(f).subject = char(subj);
        EEG.(f) = eeg_checkset(EEG.(f));
        EEG.(f) = pop_chanedit(EEG.(f), 'load', {char(f2l.elocs),'filetype','autodetect'});
        EEG.(f) = pop_chanedit(EEG.(f), 'setref',{'1:129','Cz'});
        [EEG.(f).event.latency] = deal(EEG.(f).event.sample);
        EEG.(f) = replace_event_type(EEG.(f), 'lookup_events.tsv', 1);
        EEG.(f) = eeg_checkset(EEG.(f), 'makeur');
        EEG.(f) = eeg_checkset(EEG.(f), 'chanlocs_homogeneous');
        % save the remedied EEG structure.
        pop_saveset(EEG.(f), 'filename', char(f), 'filepath', char(p2l.rawEEG_updated));
    end
    catch
        unav_dataset = [unav_dataset, string(data(i).subject)];
        unav_dataset_idx = [unav_dataset_idx i];
        warning("data from " +string(data(i).subject)+" is not available, removing corresponding entries")   
    end       
end
pInfo(unav_dataset_idx+1,:) = []; data(unav_dataset_idx) = [];


tInfo.PowerLineFrequency = 60;
%% Now we probably can call bids_export

bids_export(data, 'targetdir', char(bids_export_path), 'pInfo', pInfo, 'pInfoDesc', pInfo_desc, 'tInfo', tInfo);
