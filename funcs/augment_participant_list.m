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
all_eeg_tasks = ["RestingState",...
                "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3", ... % Visual Perception/Decision-making Paradigm
                "SurroundSupp_Block1", "SurroundSupp_Block2", ... % Inhibition/Excitation Paradigm
                "Video-DM", "Video-FF", "Video-WK", "Video-TP", ...
                "Video1", "Video2", "Video3", "Video4", ...
                "WISC_ProcSpeed", ... % WISC-IV Symbol Search Paradigm
                "vis_learn"]; % Sequence Learning Paradigm


%% load the files
clearvars -except participant_list eeg_content

plist = readtable(participant_list, "FileType", "text");
eegfiles = readtable(eeg_content, "FileType", "text", "DatetimeType", "text");

