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
target_files = ["WISC_ProcSpeed.mat","vis_learn.mat", "vis_learn6t.mat", "vis_learn8t.mat", ...
    "SurroundSupp_Block1.mat", "SurroundSupp_Block2.mat",...
    "SAIIT_2AFC_Block1.mat", "SAIIT_2AFC_Block2.mat", "SAIIT_2AFC_Block3.mat"];
if ~contains(filename, target_files), return, end
subject = string(EEG.subject);
file = beh_path + filesep + subject + "_" + filename;
beh_event = load(file);

%% main loop
if filename == "WISC_ProcSpeed.mat"  % symbol search task
    % First check if we have the same number of events
    correct_resp = readtable("symbolSearch_correct_response.tsv","filetype","text"); correct_resp_vector = reshape(correct_resp.Variables,[],1);
    subj_resp = beh_event.par.activated_resp(:,:,1);
    subj_resp_vector = reshape(subj_resp',[],1); % making the response a single vector, simialr to EEG.event.
    num_beh_resp = length(union(find(subj_resp==0), find(subj_resp==1)));
    eeg_event_idx = find(string({EEG.event(:).type})=="trialResponse");
    if num_beh_resp == length(eeg_event_idx)
        disp("Number of behavior repsonses mathces the corresponsding EEG.event items.")
    else
        error("Behavior event count is different from the EEG.event counts. Please check!")
    end
    for i = 1:num_beh_resp
        if subj_resp_vector(i) == 2
            EEG.event(eeg_event_idx(i)).user_answer = 'n/a';  % 2 does not have a meaning in this test
        else
            EEG.event(eeg_event_idx(i)).user_answer = num2str(subj_resp_vector(i));
        end
        EEG.event(eeg_event_idx(i)).correct_answer = num2str(correct_resp_vector(i));
    end
% Visual (Sequence) learning task
elseif filename == "vis_learn.mat" || filename == "vis_learn6t.mat" || filename == "vis_learn8t.mat"
    correct_resp = beh_event.par.sequence;
    subj_resp = beh_event.par.resp_click;
    % find the code for the last dot turning off
    type_toAdd_event = [32,33,34,35,50]; % the response should be added just before these events
    if beh_event.par.numrepet ~= size(beh_event.par.resp_click,1) % failsafe.
        error("EEG response count mismatches number of behavior reps in the sequence learning task, skipping adding the events")
        return
    end
    for i = 1:length(EEG.event)
        if length(correct_resp) == 10  % add target_count as a column
            EEG.event(i).target_count = num2str(8);
        else
            EEG.event(i).target_count = num2str(6);
        end
        if any(str2double(EEG.event(i).event_code) == type_toAdd_event)
            % subj response
            subj_response = regexprep(num2str(subj_resp(str2double(EEG.event(i).event_code) == type_toAdd_event,:)), '\s+', '-');
            EEG.event(i-1).user_answer = subj_response;
            EEG.event(i-1).correct_answer = regexprep(num2str(correct_resp), '\s+', '-');
        end
    end
% Surround suppresstion tasks
elseif filename == "SurroundSupp_Block1.mat" || filename == "SurroundSupp_Block2.mat"  % surround supression task
    background_cond = beh_event.BGcon; % background or no background
    background_cont_string = zeros(size(background_cond));
    background_cont_string(background_cond==1) = 1;
    forground_cont = beh_event.CNTcon; % contrast  of the foreground
    stimulus_cond = beh_event.StimCond; % Stimulus condition

    fixpoint_on = find(string({EEG.event(:).type})=="fixpoint_ON");
    stim_on = find(string({EEG.event(:).type})=="stim_ON");

    if length(stim_on) == length(fixpoint_on) && length(stim_on) == length(background_cond)
        for i = stim_on
            EEG.event(i).background = num2str(background_cont_string(i==stim_on));
            EEG.event(i).foreground_contrast = num2str(forground_cont(i==stim_on));
            EEG.event(i).stimulus_cond = num2str(stimulus_cond(i==stim_on));
            EEG.event(i).duration = 2.4*EEG.srate; % stimulation duration is hardcoded in the HBN experiment code as well.
        end
    else
        error("length of the stimulation on in EEG.event mismatches the behavior file, skipping adding the events.")
    end
% contrast change detection tasks
elseif  filename == "SAIIT_2AFC_Block1.mat" || filename == "SAIIT_2AFC_Block2.mat" || filename == "SAIIT_2AFC_Block3.mat" 
    for i = 1:length(EEG.event)
        if strcmp(EEG.event(i).type, 'right_buttonPress')
            if strcmp(EEG.event(i-1).type, 'right_target')
                EEG.event(i).feedback = 'smiley_face';
            elseif strcmp(EEG.event(i-1).type, 'left_target')
                EEG.event(i).feedback = 'sad_face';
            else
                EEG.event(i).feedback = 'non_target';
            end
        elseif strcmp(EEG.event(i).type, 'left_buttonPress')
            if strcmp(EEG.event(i-1).type, 'left_target')
                EEG.event(i).feedback = 'smiley_face';
            elseif strcmp(EEG.event(i-1).type, 'right_target')
                EEG.event(i).feedback = 'sad_face';
            else
                EEG.event(i).feedback = 'non_target';
            end
        end
    end
end