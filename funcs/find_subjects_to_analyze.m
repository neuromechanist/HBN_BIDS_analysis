function find_subjects_to_analyze(augmented_tsv, target_release, target_tasks, subj_list_toWrite)



%% initialize
clearvars -except augmented_tsv target_release target_tasks

if ~exist('augmented_tsv','var') || isempty(augmented_tsv) 
    augmented_tsv = "./tsv/participants_augmented.tsv";
else, augmented_tsv = string(augmented_tsv);
end
if ~exist('target_release','var') || isempty(target_release), target_release = "R3"; else, target_release = string(target_release); end
if ~exist('target_tasks','var') || isempty(target_tasks) 
    target_tasks = ["Video_DM", "Video_FF", "Video_TP", "Video_WK", "RestingState", ...
        "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3", "WISC_ProcSpeed", "vis_learn", ...
        "SurroundSupp_Block1", "SurroundSupp_Block2"];
else, target_tasks = string(target_tasks);
end
if ~exist('subj_list_toWrite','var') || isempty(subj_list_toWrite) 
    subj_list_toWrite = "./tsv/subjs_to_analyze.txt";
else, subj_list_toWrite = string(subj_list_toWrite);
end

%% get the subject names
plist = readtable(augmented_tsv, "FileType", "text");
target_table = plist(string(table2array(plist(:,"release_number")))==target_release,:);
subj_list = [];
for r = 1:height(target_table)
    t = target_table(r,:);
    if sum(t{1, target_tasks}) == length(target_tasks)
       subj_list = [subj_list t{1, "participant_id"}];
    end    
end

%% write the subject list
fid = fopen(subj_list_toWrite, "w");
for i = 1:length(subj_list)
    fprintf(fid, string(subj_list{i})+"\n");
end
fclose(fid);
