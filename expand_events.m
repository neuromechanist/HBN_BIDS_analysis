function EEG = expand_events(EEG, stim_file, stim_column, resample_beyond_thres)
%EXPAND_EVENTS Expands EEG.event structure with contencts of the stim_file
%   With complex electrophys tasks such as watching a movie, the task events could
%   be very long and repetitive across subjects. Instead, we can put the
%   events in a separate STIM_FILE and expand EEGLAB's EEG.event strucutre
%   only for processing. This feature will also help to plugin alternative
%   events, if a researcher comes with their own event markers and
%   annotation for the same stimulation.
%
%   INPUTS:
%       EEG: EEGLAB's EEG structure
%       STIM_FILE: The path to the stimulation file needed for EEG.event
%       expansion.
%       STIM_COLUMN: The column that should be used form the stim file to
%       expand the EEG.event. default is "VALUE".
%       RESAMPLE_BEYOND_5p: In case there is discrepancy between the
%       key_point times, should the STIM_FILE be resampled beyon 5% of it's
%       length. If the difference is <5%, the resmapling will be
%       performed. Default is 0.
%
%   OUTPUTS:
%       EEG: EEGLAB's EEG strucutre with the expanded EEG.event.
%
% (c) Seyed Yahya Shirazi, 12/2023 SCCN, INC, UCSD

%% Initialize
if ~exist('EEG','var') || isempty(EEG) || ~isstruct(EEG), error("No EEG strucutre is detected!"); end
if ~exist('stim_file','var') || isempty(stim_file)
    warning("No explicit STIM_FILE provided, will try to get it from BIDS stim directory");
    stim_file = []; % not yet implemented
end
if ~exist('stim_column','var') || isempty(stim_column)
    warning("No STIM_COLUMN is provided, will use the VALUE column of the STIM_FILE by default")
    stim_column = "value";
end
if ~exist('resample_beyond_thres','var') || isempty(resample_beyond_thres), resample_beyond_thres = 0; end

required_columns = ["onset", "duration"];
discrepancy_threshold = 0.05;

%% load and extract STIM-FILE events
opts = detectImportOptions(stim_file, "FileType", "text"); 
opts = setvartype(opts, 'string'); % crtitical to import everything as string/char
stim_table = readtable(stim_file, opts);

% check if the required columns and stim_colums are presents
if ~all(contains(required_columns,stim_table.Properties.VariableNames))
    error("required columns (i.e., ONSET and DURATION) are not in the stim file.")
end
if ~all(contains(stim_column,stim_table.Properties.VariableNames))
    error("The stim_columns provided as an input is not included in the stim file.")
end

% convert onset and duration to double entities
stim_table = convertvars(stim_table, required_columns, "double");

%% check the time discrepancy
% first find the keys points shared in EEG.event and stim_table
EEG_event_keys = string({EEG.event.type});

% find the entries with the same name in each column
for s = stim_column
    keys_present.(s).idx = find(contains(stim_table{:, s}, EEG_event_keys));
    if isempty(keys_present.(s).idx)
        warning("column" + s + " does not contain any of the keywords in the EEG.event.type. Skipping the column.")
        stim_column(s==stim_column) = [];
    else
        % If line below is confusing, EEG_event_keys: row vector, the other variable: column vector.
        keys_present.(s).map = (stim_table{:, s} == EEG_event_keys);
        keys_present.(s).eeg_event_idx = find(any(keys_present.(s).map,1));
    end
end

%% identify the time difference
discrepancy_flag = 0;
for s = stim_column
    if length(keys_present.(s).idx) == 1
        disp("The length of common values for " + s + " is ONE, so there is no time discrepancy.")
    else
        keys_present.(s).eeg_timediff = diff([EEG.event(keys_present.(s).eeg_event_idx).latency])/EEG.srate;
        keys_present.(s).timediff = diff(stim_table{keys_present.(s).idx, "onset"});
        keys_present.(s).discrepancy = abs(keys_present.(s).eeg_timediff - keys_present.(s).timediff);
        disp("The EEG.event and the " + s + " colomn has " + ...
            string(mean(keys_present.(s).discrepancy)) + " seconds difference");
    end

    if (mean(keys_present.(s).discrepancy) / max(keys_present.(s).eeg_timediff)) > (max(keys_present.(s).eeg_timediff) * discrepancy_threshold)
        discrepancy_flag = 1;
        warning("The difference between the EEG.event length and the corresponding events in the TSV file are beyon the threshold")
        if ~resample_beyond_thres, error("can't correct the timestamps, so will exit w/o results"); end
    end
end

    %% correct the time difference
duplicate_flag = 0;
for s = stim_column
    % this loop should be peformed once for columns with the same insetion points.
    if find(s==stim_column)>1 && all(keys_present.(s).map == keys_present.(stim_column(1)).map,"all")
        duplicate_flag = 1;
        break;
    end

    if ~(length(keys_present.(s).idx) == 1) && (discrepancy_flag == 0 || resample_beyond_thres)
        for i = 1:length(keys_present.(s).discrepancy)
            correct_ratio = keys_present.(s).eeg_timediff/keys_present.(s).timediff;
            stim_table{:, "onset"} = (stim_table{:, "onset"} - stim_table{keys_present.(s).idx(2*(i-1)+1), "onset"}) * correct_ratio ...
                + stim_table{keys_present.(s).idx(2*(i-1)+1), "onset"};
            stim_table{:, "duration"} = stim_table{:, "duration"} * correct_ratio;
        end
    end
end

%% pull a uniform idx to import to EEG.event
keys_present.summary.idx = [];
keys_present.summary.eeg_event_idx = [];
for s = stim_column
    keys_present.summary.idx = [keys_present.summary.idx, keys_present.(s).idx'];
    keys_present.summary.eeg_event_idx = [keys_present.summary.eeg_event_idx keys_present.(s).eeg_event_idx];
end

[uidx, ia] = unique(keys_present.summary.idx); eeg_uidx = keys_present.summary.eeg_event_idx(ia);
[keys_present.summary.uidx, is] = sort(uidx); keys_present.summary.eeg_event_uidx = eeg_uidx(is);

%% import the events to EEG.event
if length(keys_present.summary.idx) == 1, keys_present.summary.idx(end+1) = height(stim_table); end
for i = 1:length(keys_present.summary.uidx) / 2
    e0idx = keys_present.summary.eeg_event_uidx(2*(i-1)+1);  % idx0 of the segment in EEG.event
    t0idx = keys_present.summary.uidx(2*(i-1)+1);  % idx0 of the segment in the table
    temp_events = EEG.event(keys_present.summary.eeg_event_uidx(2*i):end);
    EEG.event(keys_present.summary.eeg_event_uidx(2*i):end) = [];
    for j = 0:(keys_present.summary.uidx(2*i) - keys_present.summary.uidx(2*(i-1)+1))
        EEG.event(e0idx+j).latency = EEG.event(e0idx).latency + ...
            round((stim_table{t0idx+j,"onset"} - stim_table{t0idx,"onset"}) * EEG.srate);

        for s = stim_column
            EEG.event(e0idx+j).(s) = char(stim_table{t0idx+j, s});
        end
    end
    for t = string(fieldnames(temp_events))'
        for k = 0: (length(temp_events)-1)
            EEG.event(end+k).(t) = temp_events(k+1).(t);
        end
    end
end

EEG = eeg_checkset(EEG, 'makeur');
