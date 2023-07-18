function EEG = replace_event_type(EEG, lookup_table, remove_value_column)
%REPLACE_EVNET_TYPE substitute the event names (ie, types) using a lookup table
%   It so happends that simple codes are being used as event types in
%   EEG files. Such codes would be problamtic if proper descitiption is
%   not attached. A simple fix can be replacing the event codes with their
%   short descitpiotn using a lookup table.
%
%   INPUTS:
%       EEG
%           An EEGLAB structure
%       lookup_table
%           path to the lookup table TSV file
%           The first column of the table
%           contains the codes that are being used in the EEG files and the second
%           column contains the short desciption for each code.
%   
% (c) Seyed Yahya Shirazi, 04/2023 UCSD, INC, SCCN

if ~exist('remove_value_column','var') || isempty(remove_value_column), remove_value_column = 0; end
if ~exist('lookup_table','var') || isempty(lookup_table), lookup_table = '../tsv/lookup_events.tsv'; end

% Load the lookup_events table
lookup_events = readtable(lookup_table, 'FileType', 'text', 'Delimiter', '\t');
lookup_events.code = string(lookup_events{:,"code"}); % Make the first column a string
duplicate_event_codes = ["8","12", "13", "14", "20"]; % these event codes are used for more than one event type in HBN data

% remove the value column, as it is inconsistent with the BIDS converter
if remove_value_column, EEG.event = rmfield(EEG.event, 'value'); end
% Iterate through the events in EEG.event and replace the codes
for i = 1:length(EEG.event)
    code = strtrim(EEG.event(i).type); % Remove any extra spaces
    if any(string(code) == duplicate_event_codes)
        switch string(code)
            case "8"
                if contains(EEG.setname,'contrastChange'), code = '8.1'; end
            case "12"
                if contains(EEG.setname,'contrastChange'), code = '12.1'; end
            case "13"
                if contains(EEG.setname,'contrastChange'), code = '13.1'; end
            case "14"
                if contains(EEG.setname,'symbolSearch'), code = '14.1'; end
            case "20"
                if contains(EEG.setname,'symbolSearch'), code = '20.1'; end
                
        end
    end
    index = find(strcmp(lookup_events{:, 1}, code)); % Find the corresponding index in the lookup_events table
    if ~isempty(index)
        EEG.event(i).type = lookup_events.description{index}; % Replace the code with the descriptive name
    end
end

% Iterate through the events in EEG.urevent and replace the codes
for i = 1:length(EEG.urevent)
    code = strtrim(EEG.urevent(i).type); % Remove any extra spaces
    index = find(strcmp(lookup_events{:, 1}, code)); % Find the corresponding index in the lookup_events table
    if ~isempty(index)
        EEG.urevent(i).type = lookup_events.description{index}; % Replace the code with the descriptive name
    end
end
