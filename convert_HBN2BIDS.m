function convert_HBN2BIDS(target_tasks, write_qtable)
%CONVERT_HBN2BIDS Convert HBN data to BIDS
% This script convert the list of specified tasks |task_list| to a BIDS dataset 
% uising EEGLAB's |bids_export|. Only the subjects whithin the defined |release| 
% and having all the datasets included in the |task_list| will be included in 
% the BIDS dataset.
%   INPUTS:
%       traget_tasks: Array of strings to provide the tasks (in their
%       original name) for conversion.
%       write_qtable: if set to 1, the code ONLY compiles the quality table
%       and replace it in the participants.tsv. See #23 for more details
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% Initialize
clearvars -except target_tasks write_qtable

if ~exist("target_tasks","var") || isempty(target_tasks)
    target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK", ...
    "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3",...
    "SurroundSupp_Block1", "SurroundSupp_Block2", "vis_learn", "WISC_ProcSpeed"];
end

if ~exist("write_qtable","var") || isempty(write_qtable), write_qtable = 0; end
if write_qtable, writePInfoOnly = 'on'; else, writePInfoOnly = 'off'; end

target_release = "R1";  % Can be also a string vector, but change the export path.
num_subjects = -1; % if -1, all subjects in the release will be added.

p2l = init_paths("linux", "expanse", "HBN", 1, 1);
addpath(genpath(p2l.codebase))
f2l.elocs = p2l.eegRepo + "GSN_HydroCel_129.sfp";  % f2l = file to load

plist = readtable("participants_augmented_filesize.tsv", "FileType", "text");
plist.Full_Pheno = string(plist{:,"Full_Pheno"}); % to change the variable type to string
plist.Commercial_Use = string(plist{:,"Commercial_Use"});
plist.Sex = string(plist{:,"Sex"});
plist.Sex(plist.Sex=="1") = "F"; plist.Sex(plist.Sex=="0") = "M";

% remove the dublicates
duplicate_ids = ["NDARDZ322ZFC","NDARNZ792HBN"]; % the ids were found by shell-cmd inspection upto R11.
for i = duplicate_ids, dup_idx = find(strcmp(plist{:,"participant_id"},i)); plist(dup_idx(end),:) =[]; end
plist.Properties.RowNames = plist.participant_id;

bifactor_table = readtable("HBN_cbcl_bifactor_scores_2024.tsv", "FileType", "text");
bifactors = ["P_factor", "Attention", "Internalizing", "Externalizing"];
pfactor = bifactor_table(:,["EID", bifactors]);

subjs_wo_pfactor = plist(~contains(plist{:,"participant_id"},pfactor{:,"EID"}),:);
% writetable(subjs_wo_pfactor, "subjects_missing_bfactors.tsv", "FileType", "text", "Delimiter", "\t");

pfactor(~contains(pfactor{:,"EID"},string(plist{:,"participant_id"})),:) =[];

plist(pfactor.EID, bifactors) = pfactor(:, bifactors);
plist{~contains(plist.Row,string(pfactor{:,"EID"})), bifactors} = nan;

remediedrepo = p2l.temp + target_release + "_taskBIDS_RC2/";
dpath = "/EEG/raw/mat_format/"; % downstream path after the subject
fnames = readtable("funcs/tsv/filenames.tsv", "FileType","text"); % file names, this table is compatible with `tnames`
bids_export_path = p2l.yahya + "/cmi_bids_" + target_release + "_RC2/";
no_subj_info_cols = 8; % 
tnames = string(plist.Properties.VariableNames); % task names
tnames = tnames(no_subj_info_cols+1:end);
clear EEG

f2l.quality_table = remediedrepo + target_release + "_" + string(num_subjects)+"_qulaity-table.mat";
p2l.BIDS_code = bids_export_path + "code/";
if ~exist(p2l.BIDS_code, "dir"), mkdir(p2l.BIDS_code); end
f2l.error_summary = remediedrepo + "unav_dataset-summary.mat";

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
base_info = ["participant_id","release_number","Sex","Age","EHQ_Total","Commercial_Use","Full_Pheno", bifactors];
req_info = [base_info, target_tasks];

%% define the pInfo descriptions, eInfo, eInfo descriptions, and tInfo
pInfo_desc = struct();
for i = [lower(base_info), BIDS_set_name]
    temp = load("participant_info_descriptions.mat", i);
    pInfo_desc.(i) = temp.(i);
end

eInfo = {};
if length(unique(string(BIDS_task_name))) == 1  % eInfo can't be for more than ONE task
    temp = load("event_information.mat",unique(string(BIDS_task_name)));
    eInfo = temp.(unique(string(BIDS_task_name)));
end

eInfo_desc = load("event_info_descriptions.mat");

% tInfo_basefields = ["InstitutionName", "InstitutionAddress", "Manufacturer", "ManufacturersModelName"];
% 
% tInfo = struct;
% for t = tInfo_basefields
%     tmp = load("task_info.mat", t);
%     tInfo.(t) = tmp.(t);
%     if isstring(tInfo.(t))
%         tInfo.(t) = char(tInfo.(t));
%     end
% end

% if length(unique(string(BIDS_task_name))) == 1  % eInfo can't be for more than ONE task
%     temp = load("task_info.mat",unique(string(BIDS_task_name)));
%     for m = string(fieldnames(temp.(unique(string(BIDS_task_name)))))'
%         tInfo.(m) = temp.(unique(string(BIDS_task_name))).(m);
%         if isstring(tInfo.(m))
%             tInfo.(m) = char(tInfo.(m));
%         end
%     end
% end
tInfo.PowerLineFrequency = 60; % task info, it one per experiment.

%% Create the structure as required by EEGLAB's bids export.
% While the files are not remedied and are not on EEGLAB's format, it is good 
% to have the strucutre to later on use it for adjusting the raw files and then 
% making the structure.
data = struct;
pInfo = cellstr([lower(base_info), BIDS_set_name]);
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

%% Remedy the files
% This step is similar to the import and remedy sections of step1.
if ~write_qtable
    [unav_dataset, unav_dataset_idx, err_message, err_stack, quality_table] = remedy_HBN_EEG(f2l, data, p2l, dpath, remediedrepo);

    save(f2l.quality_table, "quality_table");
    if ~exist(f2l.error_summary, "file")
        save(f2l.error_summary,"unav_dataset","err_message", "err_stack");
    else
        save(f2l.error_summary,"unav_dataset","err_stack", "err_stack", "-mat", "-append");
    end
    pInfo(unav_dataset_idx+1,:) = []; data(unav_dataset_idx) = [];
end

%% construct pInfo
if write_qtable
    load(f2l.quality_table, "quality_table");
    [pInfo, rm_id] = rawFile_quality_pInfo(pInfo,quality_table, 1, p2l.BIDS_code);
    if ~isempty(rm_id), data(unique(rm_id)) = []; end
end

%% Call bids_export

task = 'unnamed';
if length(unique(BIDS_task_name)) == 1, task = BIDS_task_name{1}; end
bids_export(data, 'targetdir', char(bids_export_path), 'pInfo', pInfo, 'pInfoDesc', pInfo_desc, 'tInfo', tInfo, ...
    'eInfo', eInfo, 'eInfoDesc', eInfo_desc, 'taskName', task, 'deleteExportDir', 'off', 'writePInfoOnly', writePInfoOnly);
