function step3p2_export_incr_toBIDS(BIDS_path, deriv_name, only_with_Raw_present, mergedSetName)
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
if ~exist('deriv_name','var') || isempty(deriv_name), deriv_name = "yahya_everyEEG"; end
if ~exist('only_with_Raw_present','var') || isempty(only_with_Raw_present), only_with_Raw_present = 1; end
if ~exist('mergedSetName','var') || isempty(mergedSetName), mergedSetName = "everyEEG"; end

EEG_files_path = "~/HBN_EEG/";

target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK", ... % videos ICs are done with videoEEG
    "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3",...
    "SurroundSupp_Block1", "SurroundSupp_Block2", "vis_learn", "WISC_ProcSpeed"];
BIDS_task_name = {'RestingState', 'DespicableMe', 'FunwithFractals', 'ThePresent', 'DiaryOfAWimpyKid',...
    'contrastChangeDetection', 'contrastChangeDetection', 'contrastChangeDetection', ...
    'surroundSupp', 'surroundSupp', 'seqLearning', 'symbolSearch'};
BIDS_run_seq = [nan,nan,nan,nan,nan,...
    1,2,3,...
    1,2,nan,nan];

p2l = init_paths("linux", "expanse", "HBN", 1, 1);

%% create a list of the datasets that have cleaned data
EEG_dir_content = dir(EEG_files_path);
target_path_prefix= "NDA";

target_ds = []; % The datasets that include incr rejection and also dipfit
target_struct_suffix = "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";

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
       EEG_file = f + "_" + mergedSetName + "_incr_" + set_to_load + ".set";
       EEG = [];
       EEG = pop_loadset('filename', char(EEG_file), 'filepath', char(EEG_path));
       EEG = update_EEG(EEG, ICA_STRUCT.(f), true);
       BIDS_filename = "sub-"+ f + "_task-" + mergedSetName +"_eeg";
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
           try
               EEG = [];
               EEG_file = f + "_" + target_tasks(t) + ".set";           
               EEG = pop_loadset('filename', char(EEG_file), 'filepath', char(EEG_path));
               EEG = update_EEG(EEG, ICA_STRUCT.(f), true);
               if isnan(BIDS_run_seq(t))
                    BIDS_filename = "sub-"+ f + "_task-" + BIDS_task_name(t) + "_eeg";
               else
                    BIDS_filename = "sub-"+ f + "_task-" + BIDS_task_name(t) + "_run-" + string(BIDS_run_seq(t)) + "_eeg";
               end
               BIDS_filepath = BIDS_path + "derivatives/" + deriv_name + "/sub-" + f + "/eeg/";
               EEG.setname = char(BIDS_filename);
               pop_saveset(EEG, 'filename', char(BIDS_filename), 'filepath', char(BIDS_filepath),...
                   'savemode', 'twofiles');
           catch
           end
       end
    end
end

