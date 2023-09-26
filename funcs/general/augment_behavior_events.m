function EEG = augment_behavior_events(EEG,task, beh_path)
%AUGMENT_BEHAVIOR_EVENTS adds behavioral events to EEG set files.
%   This function adds behavioral events to the EEG set files. These events
%   are reocrded in the behavior folder of the HBN dataset, but they are
%   required to be included in the EEG file to a successful downstream EEG
%   analysis.
%   There are three tasks that require this augmentation: visLearn, SurroundSupp
%   and WICS_ProcSpeed. 
%   This fucntions requires three inputs:
%       EEG: The EEG strucutre that needs to have augmented events.
%       task: The task names as it is recorded on raw HBN file.
%       beh_path: The path to the behavior folder for the specific
%       subject.
%
% (c) Seyed Yahya Shirazi, 09/2023 SCCN, INC, UCSD

%% initialize
subject = string(EEG.subject);
file = beh_path + filesep + subject + "_" + task + ".mat";
beh_event = load(file);

%% main loop
if task == "WISC_ProcSpeed" % This is the symbol search task
    % First check if we have the same number of events
    correct_resp = readtable();
    subj_resp = beh_event.par.activated_resp(:,:,1);
    num_beh_resp = length(union(find(subj_resp==0), find(subj_resp==1)));
    eeg_event_idx = find(string({EEG.event(:).type})=="trialResponse");
    if num_beh_resp == length(eeg_event_idx)
        disp("Number of behavior repsonses mathces the corresponsding EEG.event items.")
    else
        error("Behavior event count is different from the EEG.event counts. Please check!")
    end
    for i = 1:num_beh_resp
        
    end

end