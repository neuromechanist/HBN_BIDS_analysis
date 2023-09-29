function EEG = augment_behavior_events(EEG,filename, beh_path)
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
target_files = ["WISC_ProcSpeed.mat","vis_learn.mat","SurroundSupp_Block1.mat", "SurroundSupp_Block2.mat"];
if ~contains(filename, target_files), return, end
subject = string(EEG.subject);
file = beh_path + filesep + subject + "_" + filename;
beh_event = load(file);

%% main loop
if filename == "WISC_ProcSpeed.mat"  % symbol search task
    % First check if we have the same number of events
    correct_resp = readtable("symbolSearch_correct_response.tsv","filetype","text"); correct_resp_vector = reshape(correct_resp.Variables,[],1);
    subj_resp = beh_event.par.activated_resp(:,:,1);
    subj_resp_vector = reshape(subj_resp',[],1); % making the response a single vecotr, simialr to EEG.event.
    num_beh_resp = length(union(find(subj_resp==0), find(subj_resp==1)));
    eeg_event_idx = find(string({EEG.event(:).type})=="trialResponse");
    if num_beh_resp == length(eeg_event_idx)
        disp("Number of behavior repsonses mathces the corresponsding EEG.event items.")
    else
        error("Behavior event count is different from the EEG.event counts. Please check!")
    end
    for i = 1:num_beh_resp
        EEG.event(eeg_event_idx(i)).user_answer = subj_resp_vector(i);
        EEG.event(eeg_event_idx(i)).correct_answer = correct_resp_vector(i);
    end

elseif filename == "vis_learn.mat"  % sequence learning task
    correct_resp = beh_event.par.sequence;
    subj_resp = beh_event.par.resp_click;
    % find the code for the last dot turning off
    type_toAdd_event = [32,33,34,35,50]; % the response should be added just before these events
    if beh_event.par.numrepet ~= size(beh_event.par.resp_click,1) % failsafe.
        warning("EEG response count mismatches number of behavior reps in the sequence learning task, skipping adding the events")
        return
    end
    for i = 1:length(EEG.event)
        if any(str2double(EEG.event(i).event_code) == type_toAdd_event)
            EEG.event(i-1).user_answer = subj_resp(str2double(EEG.event(i).event_code) == type_toAdd_event,:);
            EEG.event(i-1).correct_answer = correct_resp;
        end
    end

elseif filename == "SurroundSupp_Block1.mat" || filename == "SurroundSupp_Block2.mat"  % surround supression task
    background_cont = beh_event.BGcon; % background or no background
    background_cont_string = false(size(background_cont));
    background_cont_string(background_cont==1) = true;
    forground_cont = beh_event.CNTcon; % contrast  of the forground
    stimulus_cond = beh_event.StimCond; % Stimulus condition

    stim_on = find(string({EEG.event(:).type})=="stim_ON");
    stim_off = find(string({EEG.event(:).type})=="stim_OFF");

    if length(stim_off) == length(stim_on) && length(stim_off) == length(background_cont)
        for i = stim_on
            EEG.event(i).background = background_cont_string(i==stim_on);
            EEG.event(i+1).background = background_cont_string(i==stim_on);
            EEG.event(i).forground_contrast = forground_cont(i==stim_on);
            EEG.event(i+1).forground_contrast = forground_cont(i==stim_on);
            EEG.event(i).stimulus_cond = stimulus_cond(i==stim_on);
            EEG.event(i+1).stimulus_cond = stimulus_cond(i==stim_on);            
        end
    else
        warning("legnth of the stimulation on in EEG.event mismatches the behavior file, skipping adding the events.")
    end
end