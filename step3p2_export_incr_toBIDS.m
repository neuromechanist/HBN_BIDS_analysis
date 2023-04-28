function step3p2_export_incr_toBIDS(BIDS_path, deriv_name, only_with_Raw_present)
%step3p2_export_incr_toBIDS OCnvert the end result to BIDS derivative
%   The end reuslt is inehrently a noise rejection method and dipfit
%   analysis. So, the end result should be handiliy transferrable to the
%   BIDS derivative format.
%
%   INPUTS:
%       BIDS_path: the path to the raw BIDS path
%       deriv_name: name of the folder under derivatives to store the data
%       only_with_raw_present: Only stores the final datasetst that their
%       respective raw data is avaiable. true | false, default: true
%
% (c) Seyed Yahya Shirazi, 04/2023, UCSD, INC, SCCN
%% initialize
clearvars -except BIDS_path deriv_name only_with_Raw_present
if ~exist('BIDS_path','var') || isempty(BIDS_path), warning("BIDS_path is required"); BIDS_path = "~/yahya/cmi_vid_bids_R3/";end
if ~exist('deriv_name','var') || isempty(deriv_name), deriv_name = "yahya"; end
if ~exist('only_with_Raw_present','var') || isempty(only_with_Raw_present), only_with_Raw_present = 1; end

EEG_files_path = "~/HBN_EEG/";

target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK"];
task_name_forBIDS = {'RestingState', 'DespicableMe', 'FunwithFractals', 'ThePresent', 'DiaryOfAWimpyKid'};

p2l = init_paths("linux", "expanse", "HBN", 1, 1);
addpath(genpath(p2l.codebase))

%% create a list of the datasets that have cleaned data
EEG_dir_content = dir(EEG_files_path);
target_path_prefix= "NDA";

target_ds = []; % The datasets that include incr rejection and also dipfit
target_struct_suffix = "_everyEEG_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";

i = 0;
for d = string({EEG_dir_content.name})
   i = i +1; 
   if  contains(d, target_path_prefix) && EEG_dir_content(i).isdir
       ICA_STRUCT.(d) = EEG_files_path + d + "/ICA/incr0/" + d + target_struct_suffix;
       if exist(ICA_STRUCT.(d),'file')
           ICA_STRUCT.(d) = load(ICA_STRUCT.(d));
       end
   end    
end

%% save the everyEEG datasets
for f = string(fieldnames(ICA_STRUCT)')
    if isstruct(ICA_STRUCT.(f))
       set_to_load = string(ICA_STRUCT.(f).most_brain_increments.selected_incr);
       if str2double(set_to_load) < 10, pathnum_to_load = "0" + set_to_load;
       else, pathnum_to_load = string(set_to_load);
       end
       EEG_path = EEG_files_path + f + "/ICA/incr" + pathnum_to_load + "/";
       EEG_file = f + "_everyEEG_incr_" + set_to_load + ".set";
       EEG = [];
       EEG = pop_loadset('filename', char(EEG_file), 'filepath', char(EEG_path));
       EEG = update_EEG(EEG, ICA_STRUCT.(f), true);
       BIDS_filename = "sub-"+ f + "_task-everyEEG_eeg";
       BIDS_filepath = BIDS_path + "derivatives/" + deriv_name + "/sub-" + f + "/eeg/";
       if ~exist(BIDS_filepath,'dir'), mkdir(BIDS_filepath); end
       EEG.setname = char(BIDS_filename);
       pop_saveset(EEG, 'filename', char(BIDS_filename), 'filepath', char(BIDS_filepath),...
           'savemode', 'twofiles');
    end
end

%% save individual datasets as well
for f = string(fieldnames(ICA_STRUCT)')
    if isstruct(ICA_STRUCT.(f))
       EEG_path = EEG_files_path + f + "/EEG_sets/";
       for t = 1:length(target_tasks)
           EEG = [];
           EEG_file = f + "_" + target_tasks(t) + ".set";           
           EEG = pop_loadset('filename', char(EEG_file), 'filepath', char(EEG_path));
           EEG = update_EEG(EEG, ICA_STRUCT.(f), true);
           BIDS_filename = "sub-"+ f + "_task-" + task_name_forBIDS(t) + "_eeg";
           BIDS_filepath = BIDS_path + "derivatives/" + deriv_name + "/sub-" + f + "/eeg/";
           EEG.setname = char(BIDS_filename);
           pop_saveset(EEG, 'filename', char(BIDS_filename), 'filepath', char(BIDS_filepath),...
               'savemode', 'twofiles');
       end
    end
end

