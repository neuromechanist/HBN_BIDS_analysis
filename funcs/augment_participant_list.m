function augmented_list = augment_participant_list(participant_list, eeg_content)
%AUGMENT_PARTICIPANT_LIST adds dataset availability to partictipants.tsv
%   This function add coulmns for the tasks defined in the HBN EEG study
%   and adds the dataset avalability for each task as a column.
%   For the task details see: dx.doi.org/10.1038/sdata.2017.181
%   This fucntions requires two inputs:
%       particpant_list: path to the participant.tsv downloaded from HBN
%       eeg_content: path to the eeg_content.txt created here by looking
%       into the available files on AWS S3.
%
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% EEG tasks
clearvars -except participant_list eeg_content
if ~exist('participant_list','var') || isempty(participant_list), participant_list = "funcs/tsv/participants.tsv"; else, participant_list = string(participant_list); end
if ~exist('eeg_content','var') || isempty(eeg_content), eeg_content = "funcs/tsv/eeg_content.txt"; else, eeg_content = string(eeg_content); end

all_eeg_tasks = ["RestingState",...
                "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3", ... % Visual Perception/Decision-making Paradigm
                "SurroundSupp_Block1", "SurroundSupp_Block2", ... % Inhibition/Excitation Paradigm
                "WISC_ProcSpeed", ... % WISC-IV Symbol Search Paradigm
                "vis_learn",... % Sequence Learning Paradigm
                "Video-DM", "Video-FF", "Video-WK", "Video-TP", ...
                "Video1", "Video2", "Video3", "Video4"];

%% load the files
plist = readtable(participant_list, "FileType", "text");
plist(isnan(plist{:,"Sex"}),:)=[]; % exlude the participatn if their gender is missing.
eegfiles = readtable(eeg_content, "FileType", "text", "DatetimeType", "text", ...
    "ReadVariableNames", false, "NumHeaderLines", 0);
eegfiles.Properties.VariableNames = ["date", "time", "filesize", "filename"];
eegfiles{end+1,"date"} = eegfiles{end,"date"}; eegfiles{end,"filesize"} = NaN;
%% augment the table
for p = transpose(string(plist.participant_id))
    pindex = find(eegfiles.date==p); % participant's name in the eeg_content file
    if ~isempty(pindex) % the participant might not be in the eeg-content file!
        endofp = 0; i = 1;
        while endofp == 0
            if isnan(eegfiles.filesize(pindex+i)), break; end % next subj is the next line, meaning the first subj has no data.
            for t = all_eeg_tasks
                if contains(eegfiles{pindex+i, "filename"}, t)
                    plist{plist.participant_id==p, t} = eegfiles{pindex+i, "filesize"};
                    break;
                end
            end
            i = i +1;
            if isnan(eegfiles.filesize(pindex+i))
                endofp = 1;
            end
        end
    end
end

%% save the augmented list
% first lets reorder the table to the one we have in the all_eeg_tasks
plist = renamevars(plist, "Var1", "subj_no");
column_order = [["subj_no", "participant_id", "release_number", "Sex", "Age",...
    "EHQ_Total", "Commercial_Use", "Full_Pheno"] all_eeg_tasks];
augmented_list = plist(:,column_order);

% now write the table
writetable(augmented_list, "funcs/tsv/participants_augmented_filesize.tsv", "FileType","text");