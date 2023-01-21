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

plist = readtable("./funcs/tsv/participants_augmented.tsv", "FileType","text");
plist.Full_Pheno = string(plist{:,"Full_Pheno"});
plist.Commercial_Use = string(plist{:,"Commercial_Use"});
datarepo = "~/nemar/child-mind-uncompressed/";
remediedrepo = "~/yahya/HBN/vidBIDS/";
dpath = "/EEG/raw/mat_format/"; % downstream path after the subject
fnames = readtable("funcs/tsv/filenames.tsv", "FileType","text"); % file names, this table is compatible with `tnames`
bids_export_path = "~/yahya/cmi_vid_bids/";

no_subj_inf_cols = 8;
tnames = string(plist.Properties.VariableNames); % task names
tnames = tnames(no_subj_inf_cols+1:end);
clear EEG

%% Define tasks
% Let's also define the tasks and potentially the release that we want to include 
% in the BIDS
target_tasks = ["Video_DM", "Video_FF", "Video_TP", "Video_WK", "RestingState"];
target_release = ["R3"]; %#ok<NBRAK2> 
incl_fullset_only = true; % only subjects with all datasets avalaibe will be on the BIDS

%% Create the structure as required by EEGLAB's bids export.
% While the files are not remedied and are not on EEGLAB's format, it is good 
% to have the strucutre to later on use it for adjusting the raw files and then 
% making the structure.
data = struct;
pinfo = plist.Properties.VariableNames(4:8);
target_table = plist(string(table2array(plist(:,"release_number")))==target_release,:);
for r = 1: height(target_table)
    t = target_table(r,:);
    if incl_fullset_only
        if sum(t{1, target_tasks}) == length(target_tasks)
            data(end+1).subject = char(t.participant_id);
            remedied_path = remediedrepo + string(t.participant_id) + dpath;
            data(end).raw_file = string(fnames{any(string(fnames.FIELD_NAME)==target_tasks,2),"FILE_NAME"})';
            data(end).file = cellstr(remedied_path + string(fnames{any(string(fnames.FIELD_NAME)==target_tasks,2),"FILE_NAME"})');
            pinfo = [pinfo;cellstr(t{1,4:8})];
        end
    else
        % implement the non-fullset
    end
end
data(1) = [];

%% Remedy the files
% This step is simialr to the import and remedy sections of step1.
for i = 1:length(data)
    EEG = [];
    eeg_files = data(i).raw_file;
    for f = eeg_files
        setname = split(f, ".mat");
        setname = setname(1);
        if contains(setname, "-"), setname = replace(setname, "-", "_"); end
        p2l.rawEEG = datarepo + string(data(i).subject) + dpath;
        tempload = load(p2l.rawEEG + f);
        EEG.(setname) = tempload.EEG;
    end

    for f = string(fieldnames(EEG))'
        EEG.(f).setname = char(subj + "_" + f);
        EEG.(f).subject = char(subj);
        EEG.(f) = eeg_checkset(EEG.(f));
        EEG.(f) = pop_chanedit(EEG.(f), 'load', {char(f2l.elocs),'filetype','autodetect'});
        EEG.(f) = pop_chanedit(EEG.(f), 'setref',{'1:129','Cz'});
        [EEG.(f).event.latency] = deal(EEG.(f).event.sample);
        EEG.(f) = eeg_checkset(EEG.(f), 'makeur');
        EEG.(f) = eeg_checkset(EEG.(f), 'chanlocs_homogeneous');
        % save the remedied EEG structure.
        p2l.rawEEG_updated = remediedrepo + string(data(i).subject) + dpath;
        pop_saveset(EEG.(f), 'filename', char(f), 'filepath', char(p2l.rawEEG_updated));
    end
end

%% Now we probably can call |bids_export|

bids_export(data, 'targetdir', char(bids_export_path), 'pInfo', pinfo);